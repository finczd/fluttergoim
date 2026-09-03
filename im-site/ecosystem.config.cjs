module.exports = {
  apps: [{
    name: 'chatpulse-site',
    port: 3000,
    script: '.output/server/index.mjs',
    cwd: './',
    // 从 .env.production 读环境变量，不要在此文件明文存密钥
    env_file: '.env.production',
    env: {
      NODE_ENV: 'production',
    },
    instances: 1,
    autorestart: true,
    max_memory_restart: '512M',
    kill_timeout: 5000,
    listen_timeout: 10000,
    wait_ready: true,
    error_file: './logs/pm2-error.log',
    out_file: './logs/pm2-out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss',
    merge_logs: true,
  }]
}
