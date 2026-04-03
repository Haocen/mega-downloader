import Koa from 'koa';
import Router from '@koa/router';
import bodyParser from 'koa-bodyparser';
import serve from 'koa-static';
import path from 'node:path';
import fs from 'node:fs'; // Added for directory checking
import process from 'node:process';
import { spawn } from 'node:child_process';
import { URL } from 'node:url';
import { Transform } from 'node:stream';
import { v4 as uuidv4 } from 'uuid';

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';
// New: Resolve the download directory from env
const DOWNLOAD_DIR = path.resolve(process.env.DOWNLOAD_DIR || '/downloads');
const JOB_MAX_AGE_SECONDS = process.env.JOB_MAX_AGE_SECONDS || 60 * 60 * 10;
const JOB_SYNC_WAIT_SECONDS = process.env.JOB_SYNC_WAIT_SECONDS || 5;

// Ensure the download directory exists on startup
if (!fs.existsSync(DOWNLOAD_DIR)) {
  fs.mkdirSync(DOWNLOAD_DIR, { recursive: true });
}

const app = new Koa();
const router = new Router();

app.use(bodyParser());
app.use(serve(path.join(import.meta.dirname, 'public')));

// Healthcheck endpoint
router.get('/health', async (ctx, next) => {
  ctx.status = 200;
  ctx.body = { status: 'online', downloadDir: DOWNLOAD_DIR };
  await next();
});


// In-memory store using uid as the key
const jobsUidToStatusMap = new Map();

/**
 * Creates a Transform stream that extracts percentages 
 * and updates the job store before piping to stdout.
 */
function createChildProcessTransform(pid, uid) {
  return new Transform({
    transform(chunk, encoding, callback) {
      const data = chunk.toString();

      let jobStatus = jobsUidToStatusMap.get(uid) || {};
      let updated = false;

      const parsedLines = data.split(/[\r\n]+/);
      for (const line of parsedLines) {
        const transferMatch = line.match(/\(([\d.]+)\/([\d.]+) MB:\s+([\d.]+)\s*%\)/);
        if (transferMatch) {
          jobStatus.downloadedSize = Number(transferMatch[1]);
          jobStatus.overallSize = Number(transferMatch[2]);
          jobStatus.percentage = Number(transferMatch[3]);
          jobStatus.status = 'downloading';
          jobStatus.updateTimestamp = new Date();
          updated = true;
        }

        const finishedMatch = line.match(/Download finished:\s*(.+)$/);
        if (finishedMatch) {
          const fullPath = finishedMatch?.[1]?.trim();
          jobStatus.fileName = fullPath?.split(/[/\\]/)?.pop();
          jobStatus.status = 'finished';
          jobStatus.updateTimestamp = new Date();
          updated = true;
        }

        const quotaMatch = line.match(/try again in\s+(.+)/i);
        if (quotaMatch) {
          jobStatus.error = `Try again in ${quotaMatch[1].trim()}`;
          jobStatus.updateTimestamp = new Date();
          updated = true;
        }
      }

      if (updated) {
        jobsUidToStatusMap.set(uid, jobStatus);
      }

      // Prefix child process with pid
      const lines = (encoding === 'utf8' ? chunk : data).split('\n');
      callback(null, lines.map(line => line.trim().length > 0 ? `\t[pid: ${pid}]${line}` : line).join(`\n`));
    }
  });
}

router.post('/download', async (ctx, next) => {
  const { link } = ctx.request.body;

  try {
    const parsedUrl = new URL(link);
    const allowedHosts = ['mega.nz', 'www.mega.nz', 'mega.co.nz'];

    if (!allowedHosts.includes(parsedUrl.hostname)) {
      ctx.status = 403;
      ctx.body = { error: 'Invalid Host' };
      console.warn(`Request to download ${link} is invalid`);
      return;
    }

    const uid = uuidv4();

    console.log(`Download start for ${link} with task uid ${uid}`);

    const downloadPromise = new Promise((resolve, reject) => {
      // Pass the DOWNLOAD_DIR to the 'cwd' option
      const childProcess = spawn('mega-get', [parsedUrl.href, '.'], {
        cwd: DOWNLOAD_DIR,
        stdio: [
          'inherit', // Use parent's stdin for child.
          'pipe', // Pipe child's stdout to parent.
          'pipe', // Pipe child's stderr to parent.
        ],
      });

      childProcess.on('spawn', () => {
        let jobStatus = jobsUidToStatusMap.get(uid) || {};
        jobStatus.status = 'active';
        jobStatus.startTimestamp = new Date();
        jobStatus.updateTimestamp = new Date();
        jobsUidToStatusMap.set(uid, jobStatus);
      });

      childProcess.stdout.pipe(createChildProcessTransform(childProcess?.pid, uid)).pipe(process.stdout, { end: false });
      childProcess.stderr.pipe(createChildProcessTransform(childProcess?.pid, uid)).pipe(process.stderr, { end: false });


      childProcess.on('close', (code) => {
        let jobStatus = jobsUidToStatusMap.get(uid) || {};
        jobStatus.exitCode = code;
        jobStatus.status = code !== 0 ? 'failed' : 'success';
        jobStatus.message = code !== 0 ? 'Download Failed' : 'Download Finished';
        jobStatus.endTimestamp = new Date();
        jobStatus.updateTimestamp = new Date();
        jobsUidToStatusMap.set(uid, jobStatus);

        setTimeout(() => {
          jobsUidToStatusMap.delete(uid);
        }, JOB_MAX_AGE_SECONDS * 1000);
        resolve(code);
      });
      childProcess.on('error', (err) => {
        let jobStatus = jobsUidToStatusMap.get(uid) || {};
        jobStatus.status = 'error';
        jobStatus.message = 'Download Error';
        jobStatus.error = err.message || err;
        jobStatus.updateTimestamp = new Date();
        jobsUidToStatusMap.set(uid, jobStatus);
        reject(err);
      });
    });

    const timeoutPromise = new Promise((resolve) => {
      setTimeout(() => resolve(undefined), JOB_SYNC_WAIT_SECONDS * 1000);
    });

    const exitCode = await Promise.race([downloadPromise, timeoutPromise]);

    if (exitCode === undefined) {
      ctx.body = {
        ...jobsUidToStatusMap.get(uid),
        exitCode: undefined,
        message: 'Download Started',
        path: DOWNLOAD_DIR,
        uid: uid,
      };
      console.log(`Download started in background for ${link}`);
    } else {
      ctx.body = {
        ...jobsUidToStatusMap.get(uid),
        exitCode,
        message: exitCode === 0 ? "Download Finished" : `Failed with code ${exitCode}`,
        path: DOWNLOAD_DIR, // Helpful for the UI to know where it went
        uid: uid,
      };
      console.log(`Download finished for ${link}`);
    }
  } catch (err) {
    console.error(`Download error for ${link}`, err);
    ctx.status = 400;
    ctx.body = { error: 'Processing Error', details: err.message };
  }
  await next();
});

router.post('/query', async (ctx, next) => {
  const body = ctx.request.body || {};
  const uids = Array.isArray(body) ? body : body.uids;

  if (!Array.isArray(uids)) {
    ctx.status = 400;
    ctx.body = { error: 'Please provide an array of uids' };
    await next();
    return;
  }

  const results = uids.map(uid => {
    const jobStatus = jobsUidToStatusMap.get(uid);
    if (!jobStatus) {
      return { uid, status: 'notfound' };
    }
    return { uid, ...jobStatus };
  });

  ctx.body = results;
  await next();
});

app.use(router.routes()).use(router.allowedMethods());
app.listen(PORT, HOST, () => {
  console.log(`Server at http://${HOST}:${PORT}`);
  console.log(`Downloads will be saved to: ${DOWNLOAD_DIR}`);
});
