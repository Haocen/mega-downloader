const Koa = require('koa');
const Router = require('@koa/router');
const bodyParser = require('koa-bodyparser');
const serve = require('koa-static');
const path = require('path');
const fs = require('fs'); // Added for directory checking
const { spawn } = require('child_process');
const { URL } = require('url');

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';
// New: Resolve the download directory from env
const DOWNLOAD_DIR = path.resolve(process.env.DOWNLOAD_DIR || './downloads');

// Ensure the download directory exists on startup
if (!fs.existsSync(DOWNLOAD_DIR)) {
  fs.mkdirSync(DOWNLOAD_DIR, { recursive: true });
}

const app = new Koa();
const router = new Router();

app.use(bodyParser());
app.use(serve(path.join(__dirname, 'public')));

// Healthcheck endpoint
router.get('/health', async (ctx, next) => {
  ctx.status = 200;
  ctx.body = { status: 'online', downloadDir: DOWNLOAD_DIR };
  await next();
});

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
      const process = spawn('mega-get', [parsedUrl.href, '.'], {
        cwd: DOWNLOAD_DIR,
        stdio: 'inherit',
      });

      process.on('close', (code) => resolve(code));
      process.on('error', (err) => reject(err));
    });

    ctx.body = { 
      exitCode, 
      message: exitCode === 0 ? "Download Complete" : `Failed with code ${exitCode}`,
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
