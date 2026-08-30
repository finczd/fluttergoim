<template>
  <div class="page">
    <a-card title="注册与认证" style="margin-bottom: 16px">
      <a-form>
        <a-form-item label="开放注册">
          <a-switch v-model="cfg.registerOn" @change="save('register_enabled', $event)" />
        </a-form-item>
        <a-form-item label="认证方式（短信/邮箱验证码）">
          <a-radio-group v-model="cfg.authMode" @change="save('auth_mode', $event)">
            <a-radio value="none">不认证（账号密码）</a-radio>
            <a-radio value="sms">短信认证</a-radio>
            <a-radio value="email">邮箱认证</a-radio>
          </a-radio-group>
        </a-form-item>
        <a-form-item label="邀请码注册（开启后注册页显示邀请码）">
          <a-switch v-model="cfg.inviteCodeOn" @change="save('invite_code_enabled', $event)" />
        </a-form-item>
        <a-form-item label="图形验证码（开启后注册需验证码）">
          <a-switch v-model="cfg.captchaOn" @change="save('captcha_enabled', $event)" />
        </a-form-item>
        <a-form-item label="端到端加密（服务端可解密）">
          <a-switch v-model="cfg.e2eOn" @change="save('e2e_enabled', $event)" />
        </a-form-item>
      </a-form>
    </a-card>

    <a-card title="品牌设置（登录/注册页 logo 与名称，客户端从 /auth/config 读取）" style="margin-bottom: 16px">
        <a-form-item label="Logo（上传图片自动存入 MinIO，也可直接填 URL）">
          <div style="display: flex; gap: 8px; align-items: center">
            <a-input v-model="brand.appLogo" placeholder="https://..." style="flex: 1" />
            <a-upload
              :show-file-list="false"
              :custom-request="(opt: any) => uploadToMinio(opt.file, 'brand/')"
              accept="image/*"
            >
              <a-button type="outline" :loading="uploading">上传</a-button>
            </a-upload>
          </div>
        </a-form-item>
        <a-form-item label="品牌 Logo（可选，同 appLogo）">
          <a-input v-model="brand.brandLogo" placeholder="https://..." />
        </a-form-item>
        <a-form-item label="默认头像（新注册用户使用）">
          <div style="display: flex; gap: 8px; align-items: center">
            <a-input v-model="misc.defaultAvatar" placeholder="https://...（留空则不设置）" style="flex: 1" />
            <a-upload
              :show-file-list="false"
              :custom-request="(opt: any) => uploadAvatar(opt.file)"
              accept="image/*"
            >
              <a-button type="outline" :loading="uploadingAvatar">上传</a-button>
            </a-upload>
          </div>
        </a-form-item>
        <a-form-item label="保留靓号（逗号分隔，如 8600000001,8600000002）">
          <a-input v-model="misc.reservedIds" placeholder="预留号段，注册自动跳过" />
        </a-form-item>
        <a-button type="primary" @click="saveBrand">保存品牌设置</a-button>
      </a-form>
    </a-card>

    <a-card title="App 版本与更新（客户端关于页 / 更新检查）" style="margin-bottom: 16px">
      <a-form>
        <a-form-item label="版本号">
          <a-input v-model="version.appVersion" placeholder="1.0.0" />
        </a-form-item>
        <a-form-item label="更新内容">
          <a-textarea v-model="version.updateLog" :rows="2" placeholder="本次更新说明" />
        </a-form-item>
        <a-form-item label="Android 下载地址">
          <a-input v-model="version.androidUrl" placeholder="https://..." />
        </a-form-item>
        <a-form-item label="iOS 下载地址">
          <a-input v-model="version.iosUrl" placeholder="https://..." />
        </a-form-item>
        <a-form-item label="热更新地址">
          <a-input v-model="version.hotUpdateUrl" placeholder="https://..." />
        </a-form-item>
        <a-button type="primary" @click="saveVersion">保存版本信息</a-button>
      </a-form>
    </a-card>

    <a-card title="阿里云短信（auth_mode=sms 时发送验证码）" style="margin-bottom: 16px">
      <a-form>
        <a-form-item label="AccessKey ID">
          <a-input v-model="sms.accessKey" placeholder="LTAI..." />
        </a-form-item>
        <a-form-item label="AccessKey Secret">
          <a-input-password v-model="sms.secret" placeholder="••••••" />
        </a-form-item>
        <a-form-item label="短信签名">
          <a-input v-model="sms.signName" placeholder="ChatPulse" />
        </a-form-item>
        <a-form-item label="模板 Code">
          <a-input v-model="sms.templateCode" placeholder="SMS_123456789" />
        </a-form-item>
        <a-button type="primary" @click="saveSms">保存短信配置</a-button>
      </a-form>
    </a-card>

    <a-card title="腾讯云 TRTC（音视频通话，V2.0）" style="margin-bottom: 16px">
      <a-form>
        <a-form-item label="SDKAppID">
          <a-input v-model="trtc.appId" placeholder="1400xxxxxx" />
        </a-form-item>
        <a-form-item label="SecretKey">
          <a-input-password v-model="trtc.secretKey" placeholder="••••••" />
        </a-form-item>
        <a-button type="primary" @click="saveTrtc">保存 TRTC 配置</a-button>
      </a-form>
    </a-card>

    <a-card title="MinIO 对象存储（文件/图片上传）" style="margin-bottom: 16px">
      <a-form>
        <a-form-item label="Endpoint">
          <a-input v-model="minio.endpoint" placeholder="127.0.0.1:9000" />
        </a-form-item>
        <a-form-item label="公网访问 URL（用户浏览器访问的地址）">
          <a-input v-model="minio.publicUrl" placeholder="http://localhost:9000" />
        </a-form-item>
        <a-form-item label="AccessKey">
          <a-input v-model="minio.accessKey" placeholder="minioadmin" />
        </a-form-item>
        <a-form-item label="SecretKey">
          <a-input-password v-model="minio.secretKey" placeholder="••••••" />
        </a-form-item>
        <a-form-item label="Bucket 名称">
          <a-input v-model="minio.bucket" placeholder="im-files" />
        </a-form-item>
        <a-button type="primary" @click="saveMinio">保存 MinIO 配置</a-button>
      </a-form>
    </a-card>

    <a-card title="节点服务器管理（多实例部署 / 负载均衡）" style="margin-bottom: 16px">
      <a-alert type="info" message="WS 节点列表：在「节点管理」菜单编辑保存" style="margin-bottom: 12px" />
      <a-form>
        <a-form-item label="当前节点 ID">
          <a-input v-model="infra.nodeId" placeholder="node-1（当前节点唯一标识）" />
        </a-form-item>
        <a-form-item label="JWT 签名秘钥（重启后生效）">
          <a-input-password v-model="infra.jwtSecret" placeholder="生产请用 64 位随机字符串" />
        </a-form-item>
        <a-button type="primary" @click="saveInfra">保存基础设施配置</a-button>
      </a-form>
    </a-card>

    <a-card title="系统公告（移动端消息页跑马灯横幅）">
      <a-form>
        <a-form-item label="公告内容">
          <a-textarea v-model="announcement" :rows="3" placeholder="如：欢迎使用 ChatPulse! 请注意账号安全，不要泄露验证码。" />
        </a-form-item>
        <a-button type="primary" @click="saveAnnouncement">保存公告</a-button>
      </a-form>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Message } from '@arco-design/web-vue'
import { adminApi } from '@/api/admin'

const cfg = ref({ registerOn: true, authMode: 'none' as string, inviteCodeOn: false, captchaOn: false, e2eOn: false })
const brand = ref({ appName: '', brandName: '', appLogo: '', brandLogo: '' })
const version = ref({ appVersion: '', updateLog: '', androidUrl: '', iosUrl: '', hotUpdateUrl: '' })
const sms = ref({ accessKey: '', secret: '', signName: '', templateCode: '' })
const trtc = ref({ appId: '', secretKey: '' })
const minio = ref({ endpoint: '', publicUrl: '', accessKey: '', secretKey: '', bucket: '' })
const infra = ref({ nodeId: '', jwtSecret: '' })
const announcement = ref('')
const uploading = ref(false)
const uploadingAvatar = ref(false)
const misc = ref({ defaultAvatar: '', reservedIds: '' })

// 需求7：上传文件到 MinIO（后端 /api/v1/upload），返回 URL 填入 Logo
async function uploadToMinio(file: File, dir: string) {
  uploading.value = true
  try {
    const fd = new FormData()
    fd.append('file', file)
    fd.append('dir', dir)
    const token = localStorage.getItem('im-token') || ''
    const resp = await fetch('/api/v1/upload', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: fd
    })
    const json = await resp.json()
    if (json.code === 0) {
      brand.value.appLogo = json.data.url
      Message.success('上传成功，点击「保存品牌设置」生效')
    } else {
      Message.error(json.message || '上传失败')
    }
  } catch (e: any) {
    Message.error('上传失败：' + (e?.message || ''))
  } finally {
    uploading.value = false
  }
}

onMounted(async () => {
  const flagKeys = ['register_enabled', 'auth_mode', 'invite_code_enabled', 'captcha_enabled', 'e2e_enabled']
  const [r, a, i, ca, e] = await Promise.all(flagKeys.map((k) => adminApi.configGet(k)))
  cfg.value = {
    registerOn: !!r.data.data,
    authMode: String(a.data.data || 'none'),
    inviteCodeOn: !!i.data.data,
    captchaOn: !!ca.data.data,
    e2eOn: !!e.data.data
  }
  const strKeys = ['app_name', 'brand_name', 'app_logo', 'brand_logo']
  const [an, bn, al, bl] = await Promise.all(strKeys.map((k) => adminApi.configGet(k)))
  brand.value = {
    appName: String(an.data.data || ''),
    brandName: String(bn.data.data || ''),
    appLogo: String(al.data.data || ''),
    brandLogo: String(bl.data.data || '')
  }
  const verKeys = ['app_version', 'update_log', 'android_url', 'ios_url', 'hot_update_url']
  const [v, ul, ad, io, hu] = await Promise.all(verKeys.map((k) => adminApi.configGet(k)))
  version.value = {
    appVersion: String(v.data.data || ''),
    updateLog: String(ul.data.data || ''),
    androidUrl: String(ad.data.data || ''),
    iosUrl: String(io.data.data || ''),
    hotUpdateUrl: String(hu.data.data || '')
  }
  const smsKeys = ['sms_access_key', 'sms_secret', 'sms_sign_name', 'sms_template_code']
  const [sk, ss, sn, st] = await Promise.all(smsKeys.map((k) => adminApi.configGet(k)))
  sms.value = {
    accessKey: String(sk.data.data || ''),
    secret: String(ss.data.data || ''),
    signName: String(sn.data.data || ''),
    templateCode: String(st.data.data || '')
  }
  const trtcKeys = ['trtc_app_id', 'trtc_secret_key']
  const [ta, tk] = await Promise.all(trtcKeys.map((k) => adminApi.configGet(k)))
  trtc.value = { appId: String(ta.data.data || ''), secretKey: String(tk.data.data || '') }
  const minioKeys = ['minio_endpoint', 'minio_public_url', 'minio_access_key', 'minio_secret_key', 'minio_bucket']
  const [me, mu, mk, ms, mb] = await Promise.all(minioKeys.map((k) => adminApi.configGet(k)))
  minio.value = {
    endpoint: String(me.data.data || ''),
    publicUrl: String(mu.data.data || ''),
    accessKey: String(mk.data.data || ''),
    secretKey: String(ms.data.data || ''),
    bucket: String(mb.data.data || '')
  }
  const infraKeys = ['node_id', 'jwt_secret']
  const [ni, js] = await Promise.all(infraKeys.map((k) => adminApi.configGet(k)))
  infra.value = { nodeId: String(ni.data.data || ''), jwtSecret: String(js.data.data || '') }
  const miscKeys = ['default_avatar', 'reserved_short_ids']
  const [da, ri] = await Promise.all(miscKeys.map((k) => adminApi.configGet(k)))
  misc.value = { defaultAvatar: String(da.data.data || ''), reservedIds: String(ri.data.data || '') }
  const ann = await adminApi.configGet('announcement')
  announcement.value = String(ann.data.data || '')
})

async function save(key: string, value: unknown) {
  const { data } = await adminApi.configSet(key, value)
  if (data.code === 0) Message.success('已保存')
  else Message.error(data.message)
}

async function saveBrand() {
  await Promise.all([
    adminApi.configSet('app_name', brand.value.appName),
    adminApi.configSet('brand_name', brand.value.brandName),
    adminApi.configSet('app_logo', brand.value.appLogo),
    adminApi.configSet('brand_logo', brand.value.brandLogo),
    adminApi.configSet('default_avatar', misc.value.defaultAvatar),
    adminApi.configSet('reserved_short_ids', misc.value.reservedIds)
  ])
  Message.success('品牌设置已保存')
}

// 需求7：默认头像上传到 MinIO
async function uploadAvatar(file: File) {
  uploadingAvatar.value = true
  try {
    const fd = new FormData()
    fd.append('file', file)
    fd.append('dir', 'avatar/')
    const token = localStorage.getItem('im-token') || ''
    const resp = await fetch('/api/v1/upload', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: fd
    })
    const json = await resp.json()
    if (json.code === 0) {
      misc.value.defaultAvatar = json.data.url
      Message.success('默认头像已上传，点击「保存品牌设置」生效')
    } else Message.error(json.message || '上传失败')
  } catch (e: any) {
    Message.error('上传失败：' + (e?.message || ''))
  } finally {
    uploadingAvatar.value = false
  }
}

async function saveVersion() {
  await Promise.all([
    adminApi.configSet('app_version', version.value.appVersion),
    adminApi.configSet('update_log', version.value.updateLog),
    adminApi.configSet('android_url', version.value.androidUrl),
    adminApi.configSet('ios_url', version.value.iosUrl),
    adminApi.configSet('hot_update_url', version.value.hotUpdateUrl)
  ])
  Message.success('版本信息已保存')
}

async function saveSms() {
  await Promise.all([
    adminApi.configSet('sms_access_key', sms.value.accessKey),
    adminApi.configSet('sms_secret', sms.value.secret),
    adminApi.configSet('sms_sign_name', sms.value.signName),
    adminApi.configSet('sms_template_code', sms.value.templateCode)
  ])
  Message.success('短信配置已保存')
}

async function saveTrtc() {
  await Promise.all([
    adminApi.configSet('trtc_app_id', trtc.value.appId),
    adminApi.configSet('trtc_secret_key', trtc.value.secretKey)
  ])
  Message.success('TRTC 配置已保存')
}

async function saveMinio() {
  await Promise.all([
    adminApi.configSet('minio_endpoint', minio.value.endpoint),
    adminApi.configSet('minio_public_url', minio.value.publicUrl),
    adminApi.configSet('minio_access_key', minio.value.accessKey),
    adminApi.configSet('minio_secret_key', minio.value.secretKey),
    adminApi.configSet('minio_bucket', minio.value.bucket)
  ])
  Message.success('MinIO 配置已保存')
}

async function saveInfra() {
  await Promise.all([
    adminApi.configSet('node_id', infra.value.nodeId),
    adminApi.configSet('jwt_secret', infra.value.jwtSecret)
  ])
  Message.success('基础设施配置已保存')
}

async function saveAnnouncement() {
  await adminApi.configSet('announcement', announcement.value)
  Message.success('公告已保存')
}
</script>
