// POST /api/admin/upload — multipart file upload, saves to <PROJECT_ROOT>/public/uploads/
// Returns { code: 0, data: { url: '/uploads/xxx.jpg', size } }
//
// NOTE: we deliberately compute the writable path relative to the Nitro runtime:
//   - In dev / preview : cwd = project root  => public/uploads/
//   - In production    : cwd = <project>/.output/server (PM2 runs node index.mjs here)
//                         => we walk up two levels to project root, then public/uploads.
// This keeps uploaded files OUTSIDE the build directory, so upgrades (which replace
// .output/ entirely) will never destroy user uploads, and Nginx can serve them with a
// simple `location ^~ /uploads/ { root <project-root>/public; }` rule.
import { mkdir, writeFile } from 'node:fs/promises'
import { join, resolve, basename, extname } from 'node:path'
import { randomUUID } from 'node:crypto'
import { existsSync, mkdirSync } from 'node:fs'

const ALLOWED_EXT = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.bmp']
const MAX_SIZE = 10 * 1024 * 1024 // 10 MB

/**
 * Resolve the real, persistent public/uploads directory.
 * Priority:
 *   1) process.env.PUBLIC_UPLOAD_DIR (absolute path, explicit override)
 *   2) If cwd looks like a Nitro .output/server directory (contains package.json and
 *      index.mjs at top-level) we resolve to ../../public/uploads
 *   3) Otherwise use <cwd>/public/uploads
 */
function resolveWritableUploadsDir(): string {
  if (process.env.PUBLIC_UPLOAD_DIR) {
    return process.env.PUBLIC_UPLOAD_DIR
  }
  const cwd = process.cwd()
  const looksLikeNitroOutputServer =
    existsSync(join(cwd, 'package.json')) && existsSync(join(cwd, 'index.mjs'))
  const projectRoot = looksLikeNitroOutputServer ? resolve(cwd, '..', '..') : cwd
  const dir = resolve(projectRoot, 'public', 'uploads')
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  return dir
}

export default defineEventHandler(async (event) => {
  let formData: FormData
  try {
    formData = await readFormData(event)
  } catch (err: any) {
    setResponseStatus(event, 400)
    return { code: 400, message: '请求体解析失败，请确认是 multipart/form-data：' + (err?.message || '') }
  }

  const file = formData.get('file') as any
  if (!file || !(file instanceof Blob || (file && file.arrayBuffer && typeof file.arrayBuffer === 'function'))) {
    setResponseStatus(event, 400)
    return { code: 400, message: '缺少文件字段 file，或文件为空' }
  }

  const originalName = String((file as any).name || 'img').toLowerCase()
  const ext = extname(originalName) || '.jpg'
  if (!ALLOWED_EXT.includes(ext)) {
    setResponseStatus(event, 400)
    return { code: 400, message: `不支持的文件类型 ${ext}，允许：${ALLOWED_EXT.join(' ')}` }
  }

  let bytes: Uint8Array
  try {
    const buf = await file.arrayBuffer()
    bytes = new Uint8Array(buf)
  } catch (err: any) {
    setResponseStatus(event, 500)
    return { code: 500, message: '读取文件失败: ' + (err?.message || '') }
  }

  if (bytes.length === 0) {
    setResponseStatus(event, 400)
    return { code: 400, message: '文件内容为空' }
  }
  if (bytes.length > MAX_SIZE) {
    setResponseStatus(event, 400)
    return { code: 400, message: `文件过大（${Math.round(bytes.length / 1024)}KB），最大允许 10MB` }
  }

  const uploadDir = resolveWritableUploadsDir()
  try {
    await mkdir(uploadDir, { recursive: true })
  } catch (err: any) {
    setResponseStatus(event, 500)
    return { code: 500, message: '创建上传目录失败: ' + (err?.message || uploadDir) }
  }

  const savedName = `${randomUUID()}${ext}`
  const fullPath = join(uploadDir, savedName)
  try {
    await writeFile(fullPath, bytes)
  } catch (err: any) {
    setResponseStatus(event, 500)
    return { code: 500, message: '保存文件失败 (' + fullPath + '): ' + (err?.message || '') }
  }

  // Silence unused-import warning for `basename` in strict TS projects.
  // We keep it here only to guarantee consistency if later we want human-readable stems.
  void basename
  return { code: 0, data: { url: `/uploads/${savedName}`, size: bytes.length } }
})
