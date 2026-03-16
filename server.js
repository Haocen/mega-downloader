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

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';
// New: Resolve the download directory from env
const DOWNLOAD_DIR = path.resolve(process.env.DOWNLOAD_DIR || '/downloads');

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


// In-memory store using PID as the key
// const downloadJobs = new Map();

/**
 * Creates a Transform stream that extracts percentages 
 * and updates the job store before piping to stdout.
 */
function createChildProcessTransform(pid) {
  return new Transform({
    transform(chunk, encoding, callback) {
      const data = chunk.toString();

      // Update the progress in our Map if we find a percentage
      // const match = data.match(/(\d+\.?\d*\s*%)/);
      // if (match && downloadJobs.has(pid)) {
      //   downloadJobs.get(pid).progress = match[0].trim();
      // }

      // Prefix child process with pid
      const lines = (encoding === 'utf8' ? chunk : chunk.toString()).split('\n');
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

    console.log(`Download start for ${link}`);

    const exitCode = await new Promise((resolve, reject) => {
      // Pass the DOWNLOAD_DIR to the 'cwd' option
      const childProcess = spawn('mega-get', [parsedUrl.href, '.'], {
        cwd: DOWNLOAD_DIR,
        stdio: [
          'inherit', // Use parent's stdin for child.
          'pipe', // Pipe child's stdout to parent.
          'pipe', // Pipe child's stderr to parent.
        ],
      });

      childProcess.stdout.pipe(createChildProcessTransform(childProcess?.pid)).pipe(process.stdout, { end: false });
      childProcess.stderr.pipe(createChildProcessTransform(childProcess?.pid)).pipe(process.stderr, { end: false });

      childProcess.on('close', (code) => resolve(code));
      childProcess.on('error', (err) => reject(err));
    });

    ctx.body = {
      exitCode,
      message: exitCode === 0 ? "Download Finished" : `Failed with code ${exitCode}`,
      path: DOWNLOAD_DIR // Helpful for the UI to know where it went
    };

    console.log(`Download finished for ${link}`);
  } catch (err) {
    console.error(`Download error for ${link}`, err);
    ctx.status = 400;
    ctx.body = { error: 'Processing Error', details: err.message };
  }
  await next();
});

app.use(router.routes()).use(router.allowedMethods());
app.listen(PORT, HOST, () => {
  console.log(`Server at http://${HOST}:${PORT}`);
  console.log(`Downloads will be saved to: ${DOWNLOAD_DIR}`);
});
