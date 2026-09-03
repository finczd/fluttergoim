<template>
  <div class="config-page">
    <!-- 左侧分区导航 -->
    <aside class="config-nav">
      <button
        v-for="s in sections"
        :key="s.key"
        class="nav-btn"
        :class="{ active: activeSection === s.key }"
        @click="activeSection = s.key"
      >
        <component :is="s.icon" />
        <span>{{ s.title }}</span>
      </button>
    </aside>

    <!-- 右侧内容 -->
    <div class="config-body">
      <!-- 品牌 -->
      <div v-show="activeSection === 'brand'" class="section">
        <h2 class="section-title">品牌设置</h2>
        <p class="section-desc">登录/注册页 Logo 与名称，客户端从 /auth/config 读取</p>

        <a-card class="form-card brand-card">
          <a-form layout="vertical" :label-col-props="{ span: 24 }">
            <a-form-item label="应用名称">
              <a-input v-model="brand.appName" placeholder="如：ChatPulse" />
            </a-form-item>
            <a-form-item label="品牌名称">
              <a-input v-model="brand.brandName" placeholder="如：ChatPulse" />
            </a-form-item>
            <a-form-item label="应用 Logo">
              <ImageUpload v-model="brand.appLogo" dir="brand/" :inline="true" :size="96" hint="建议尺寸 128×128，PNG/SVG。登录页 / 关于页左上角展示。" />
            </a-form-item>
            <a-form-item label="品牌 Logo（可选）">
              <ImageUpload v-model="brand.brandLogo" dir="brand/" :inline="true" :size="96" hint="用于品牌展示位。留空则使用应用 Logo。" />
            </a-form-item>
            <a-form-item label="默认头像（新注册用户使用）">
              <ImageUpload v-model="misc.defaultAvatar" dir="avatar/" round :inline="true" :size="96" hint="圆形预览，留空则使用系统默认头像。" />
            </a-form-item>
            <div class="form-actions">
              <a-button type="primary" @click="saveBrand">保存品牌设置</a-button>
            </div>
          </a-form>
        </a-card>
      </div>

      <!-- 注册与认证 -->
      <div v-show="activeSection === 'auth'" class="section">
        <h2 class="section-title">注册与认证</h2>
        <p class="section-desc">控制账号注册与登录认证方式</p>

        <a-card class="form-card">
          <a-form layout="vertical" :model="cfg">
            <a-form-item label="开放注册">
              <a-switch v-model="cfg.registerOn" @change="save('register_enabled', $event)" />
            </a-form-item>
            <a-form-item label="认证方式">
              <a-radio-group v-model="cfg.authMode" @change="save('auth_mode', $event)">
                <a-radio value="none">不认证（账号密码）</a-radio>
                <a-radio value="sms">短信认证</a-radio>
                <a-radio value="email">邮箱认证</a-radio>
              </a-radio-group>
            </a-form-item>
            <a-form-item label="邀请码注册">
              <a-switch v-model="cfg.inviteCodeOn" @change="save('invite_code_enabled', $event)" />
            </a-form-item>
            <a-form-item label="图形验证码">
              <a-switch v-model="cfg.captchaOn" @change="save('captcha_enabled', $event)" />
            </a-form-item>
            <a-form-item label="端到端加密（服务端可解密）">
              <a-switch v-model="cfg.e2eOn" @change="save('e2e_enabled', $event)" />
            </a-form-item>
          </a-form>
        </a-card>
      </div>

      <!-- 功能开关 -->
      <div v-show="activeSection === 'feature'" class="section">
        <h2 class="section-title">功能开关</h2>
        <p class="section-desc">控制客户端功能入口的显示，App 端从 /auth/config 实时读取</p>

        <a-card class="form-card">
          <a-form layout="vertical">
            <a-form-item label="开启零钱">
              <a-switch v-model="feature.walletOn" @change="save('wallet_enabled', $event)" />
              <template #extra>
                关闭后：聊天窗口不显示红包/转账入口，用户中心不显示「我的钱包」
              </template>
            </a-form-item>
            <a-form-item label="开启邀请码">
              <a-switch v-model="feature.inviteOn" @change="save('invite_feature_enabled', $event)" />
              <template #extra>
                关闭后：用户中心不显示「我的邀请码」。注意与「注册认证」中的「邀请码注册」（注册是否强制填码）相互独立
              </template>
            </a-form-item>
          </a-form>
        </a-card>
      </div>

      <!-- 客服设置 -->
      <div v-show="activeSection === 'kefu'" class="section">
        <h2 class="section-title">客服设置</h2>
        <p class="section-desc">先在「用户管理」把用户角色设为「客服」，新注册用户将按下方配置自动添加客服为好友</p>

        <a-card class="form-card">
          <a-form layout="vertical" :model="kefu">
            <a-form-item label="注册自动添加客服">
              <a-switch v-model="kefu.autoAdd" @change="saveKefu" />
            </a-form-item>
            <a-form-item label="添加方式">
              <a-radio-group v-model="kefu.mode" @change="saveKefu">
                <a-radio value="round">轮流（每位新用户分配一位客服）</a-radio>
                <a-radio value="all">全部（添加所有客服）</a-radio>
              </a-radio-group>
            </a-form-item>
            <a-form-item label="客服自动打招呼内容">
              <a-textarea v-model="kefu.greeting" :rows="3" :max-length="200" show-word-limit
                          placeholder="例如：你好，我是 {nickname}，很高兴为您服务~（{nickname} 会被替换成客服昵称）" />
              <div style="color: #86909c; font-size: 12px; margin-top: 4px">
                留空则不发送；支持 <code style="background:#f2f3f5;padding:1px 4px;border-radius:3px">{nickname}</code> 占位符自动替换为客服昵称。
              </div>
            </a-form-item>
            <a-form-item>
              <a-button type="primary" :loading="savingKefu" @click="saveKefu">保存客服设置</a-button>
            </a-form-item>
          </a-form>
        </a-card>
      </div>

      <!-- App 版本 -->
      <div v-show="activeSection === 'version'" class="section">
        <h2 class="section-title">App 版本与更新</h2>
        <p class="section-desc">客户端关于页 / 更新检查</p>

        <a-card class="form-card">
          <a-form layout="vertical">
            <a-form-item label="版本号">
              <a-input v-model="version.appVersion" placeholder="1.0.0" />
            </a-form-item>
            <a-form-item label="更新内容">
              <a-textarea v-model="version.updateLog" :rows="3" placeholder="本次更新说明" />
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
      </div>

      <!-- 通知 -->
      <div v-show="activeSection === 'notify'" class="section">
        <h2 class="section-title">系统公告</h2>
        <p class="section-desc">移动端消息页跑马灯横幅</p>

        <a-card class="form-card">
          <a-form layout="vertical">
            <a-form-item label="公告内容">
              <a-textarea v-model="announcement" :rows="4" placeholder="如：欢迎使用 ChatPulse! 请注意账号安全，不要泄露验证码。" />
            </a-form-item>
            <a-button type="primary" @click="saveAnnouncement">保存公告</a-button>
          </a-form>
        </a-card>
      </div>

      <!-- 存储 -->
      <div v-show="activeSection === 'storage'" class="section">
        <h2 class="section-title">MinIO 对象存储</h2>
        <p class="section-desc">文件/图片上传存储</p>

        <a-card class="form-card">
          <a-form layout="vertical" :model="minio">
            <a-form-item label="Endpoint">
              <a-input v-model="minio.endpoint" placeholder="127.0.0.1:9000" />
            </a-form-item>
            <a-form-item label="公网访问 URL">
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
      </div>

      <!-- 短信 -->
      <div v-show="activeSection === 'sms'" class="section">
        <h2 class="section-title">阿里云短信</h2>
        <p class="section-desc">auth_mode=sms 时发送验证码</p>

        <a-card class="form-card">
          <a-form layout="vertical" :model="sms">
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
      </div>

      <!-- 音视频 -->
      <div v-show="activeSection === 'trtc'" class="section">
        <h2 class="section-title">腾讯云 TRTC</h2>
        <p class="section-desc">音视频通话（V2.0）</p>

        <a-card class="form-card">
          <a-form layout="vertical">
            <a-form-item label="SDKAppID">
              <a-input v-model="trtc.appId" placeholder="1400xxxxxx" />
            </a-form-item>
            <a-form-item label="SecretKey">
              <a-input-password v-model="trtc.secretKey" placeholder="••••••" />
            </a-form-item>
            <a-button type="primary" @click="saveTrtc">保存 TRTC 配置</a-button>
          </a-form>
        </a-card>
      </div>

      <!-- 推送（极光） -->
      <div v-show="activeSection === 'jpush'" class="section">
        <h2 class="section-title">推送（极光）</h2>
        <p class="section-desc">App 离线消息推送：接收方不在线时，服务端按极光 alias（=用户 ID）下发系统通知。参数在极光控制台「应用管理」获取</p>

        <a-card class="form-card">
          <a-form layout="vertical" :model="jpush">
            <a-form-item label="启用离线推送">
              <a-switch v-model="jpush.enabled" />
            </a-form-item>
            <a-form-item label="AppKey">
              <a-input v-model="jpush.appKey" placeholder="极光控制台的应用 AppKey" />
            </a-form-item>
            <a-form-item label="Master Secret">
              <a-input-password v-model="jpush.masterSecret" placeholder="••••••" />
            </a-form-item>
            <a-form-item label="iOS APNs 生产环境">
              <a-switch v-model="jpush.apnsProduction" />
              <template #extra>开发调试用开发环境（关）；正式上架后开启（开），否则 iOS 真机收不到推送</template>
            </a-form-item>
            <a-button type="primary" @click="saveJpush">保存推送配置</a-button>
          </a-form>
        </a-card>
      </div>

      <!-- 节点 -->
      <div v-show="activeSection === 'infra'" class="section">
        <h2 class="section-title">节点服务器</h2>
        <p class="section-desc">多实例部署 / 负载均衡</p>

        <a-card class="form-card">
          <a-alert type="info" message="WS 节点列表在「节点管理」菜单编辑保存；JWT 签名秘钥由部署环境变量 JWT_SECRET 提供（deploy/.env），不要在后台配置——修改 .env 后需重启 api 容器" style="margin-bottom: 16px" />
          <a-form layout="vertical" :model="infra">
            <a-form-item label="当前节点 ID">
              <a-input v-model="infra.nodeId" placeholder="node-1（当前节点唯一标识）" />
            </a-form-item>
            <a-button type="primary" @click="saveInfra">保存节点配置</a-button>
          </a-form>
        </a-card>
      </div>

      <!-- 支付配置（在对象存储的下一块） -->
      <div v-show="activeSection === 'pay'" class="section pay-section">
        <h2 class="section-title">
          <span style="display:inline-flex;align-items:center;gap:8px">
            <IconQrcode style="font-size:20px;color:var(--color-primary-6)" />
            支付配置
          </span>
        </h2>
        <p class="section-desc">平台充值收款二维码、提现费率与门槛；客户端通过 <code>GET /api/v1/pay/config</code> 读取</p>

        <!-- 单卡片包住 Tab 内所有内容 -->
        <a-card class="pay-card" :bordered="false">
          <a-tabs default-active-key="channels" class="pay-tabs" :lazy-load="true">
            <!-- ================== Tab1：充值通道 ================== -->
            <a-tab-pane key="channels">
              <template #title>
                <span class="tab-title"><IconWechatpay style="color:#07c160" /> 充值通道</span>
              </template>

              <!-- 充值开关 头 -->
              <div class="pay-row head-row">
                <div>
                  <div class="row-title">充值通道开关</div>
                  <div class="row-desc">关闭后客户端「充值」页会显示「暂未开放充值」</div>
                </div>
                <a-switch v-model="pay.enabled" />
              </div>

              <!-- 收款码 3 列（内部分区，不再套 3 张独立 a-card） -->
              <div class="pay-divider">收款码</div>
              <div class="channels-grid">
                <div class="ch wechat">
                  <div class="ch-head">
                    <span class="ch-brand"><IconWechat /> 微信</span>
                    <a-tag v-if="pay.receiveWechatQrcodeUrl" color="green">已配置</a-tag>
                    <a-tag v-else color="gray">待上传</a-tag>
                  </div>
                  <div class="ch-main">
                    <ImageUpload
                      v-model="pay.receiveWechatQrcodeUrl"
                      dir="pay/qrcodes/"
                      :size="200"
                      hint="用户用微信扫码给平台打款"
                    />
                    <div class="ch-ops">
                      <a-button
                        type="outline"
                        size="small"
                        :disabled="!pay.receiveWechatQrcodeUrl"
                        @click="openQrPreview(pay.receiveWechatQrcodeUrl,'微信收款码')"
                      >
                        <template #icon><IconEye /></template>
                        查看大图
                      </a-button>
                      <a-popconfirm
                        :disabled="!pay.receiveWechatQrcodeUrl"
                        content="确定清除微信收款码？"
                        @ok="pay.receiveWechatQrcodeUrl = ''"
                      >
                        <a-button
                          size="small"
                          status="warning"
                          :disabled="!pay.receiveWechatQrcodeUrl"
                        >
                          <template #icon><IconDelete /></template>
                          清除
                        </a-button>
                      </a-popconfirm>
                    </div>
                  </div>
                </div>

                <div class="ch alipay">
                  <div class="ch-head">
                    <span class="ch-brand"><IconAlipayCircle /> 支付宝</span>
                    <a-tag v-if="pay.receiveAlipayQrcodeUrl" color="blue">已配置</a-tag>
                    <a-tag v-else color="gray">待上传</a-tag>
                  </div>
                  <div class="ch-main">
                    <ImageUpload
                      v-model="pay.receiveAlipayQrcodeUrl"
                      dir="pay/qrcodes/"
                      :size="200"
                      hint="用户用支付宝扫码给平台打款"
                    />
                    <div class="ch-ops">
                      <a-button
                        type="outline"
                        size="small"
                        :disabled="!pay.receiveAlipayQrcodeUrl"
                        @click="openQrPreview(pay.receiveAlipayQrcodeUrl,'支付宝收款码')"
                      >
                        <template #icon><IconEye /></template>
                        查看大图
                      </a-button>
                      <a-popconfirm
                        :disabled="!pay.receiveAlipayQrcodeUrl"
                        content="确定清除支付宝收款码？"
                        @ok="pay.receiveAlipayQrcodeUrl = ''"
                      >
                        <a-button
                          size="small"
                          status="warning"
                          :disabled="!pay.receiveAlipayQrcodeUrl"
                        >
                          <template #icon><IconDelete /></template>
                          清除
                        </a-button>
                      </a-popconfirm>
                    </div>
                  </div>
                </div>

                <div class="ch bank">
                  <div class="ch-head">
                    <span class="ch-brand"><IconExport /> 银行卡</span>
                    <a-tag v-if="pay.receiveBankQrcodeUrl || pay.receiveBankInfo.cardNo" color="orangered">已配置</a-tag>
                    <a-tag v-else color="gray">待上传</a-tag>
                  </div>
                  <div class="ch-main">
                    <ImageUpload
                      v-model="pay.receiveBankQrcodeUrl"
                      dir="pay/qrcodes/"
                      :size="200"
                      hint="银行卡转账二维码 / 收款截图"
                    />
                    <div class="ch-ops">
                      <a-button
                        type="outline"
                        size="small"
                        :disabled="!pay.receiveBankQrcodeUrl"
                        @click="openQrPreview(pay.receiveBankQrcodeUrl,'银行卡二维码/转账截图')"
                      >
                        <template #icon><IconEye /></template>
                        查看大图
                      </a-button>
                      <a-popconfirm
                        :disabled="!pay.receiveBankQrcodeUrl"
                        content="确定清除银行卡二维码图？"
                        @ok="pay.receiveBankQrcodeUrl = ''"
                      >
                        <a-button
                          size="small"
                          status="warning"
                          :disabled="!pay.receiveBankQrcodeUrl"
                        >
                          <template #icon><IconDelete /></template>
                          清除
                        </a-button>
                      </a-popconfirm>
                    </div>
                  </div>
                </div>
              </div>

              <!-- 银行卡文字信息（在同一张卡片内） -->
              <div class="pay-divider">银行卡信息 <span class="d-sub">（用户未扫收款码时展示文字）</span></div>
              <a-form layout="vertical" :label-col-props="{ span: 24 }">
                <a-row :gutter="16">
                  <a-col :xs="24" :sm="24" :md="8">
                    <a-form-item label="开户银行">
                      <a-input v-model="pay.receiveBankInfo.bankName" allow-clear placeholder="如：招商银行深圳南山支行" />
                    </a-form-item>
                  </a-col>
                  <a-col :xs="24" :sm="24" :md="8">
                    <a-form-item label="银行卡号">
                      <a-input v-model="pay.receiveBankInfo.cardNo" allow-clear placeholder="与持卡人一致的收款卡号" />
                    </a-form-item>
                  </a-col>
                  <a-col :xs="24" :sm="24" :md="8">
                    <a-form-item label="开户姓名">
                      <a-input v-model="pay.receiveBankInfo.accountName" allow-clear placeholder="持卡人真实姓名" />
                    </a-form-item>
                  </a-col>
                </a-row>
              </a-form>

              <!-- 充值提示（在同一张卡片内） -->
              <div class="pay-divider">充值提示 <span class="d-sub">（客户端充值页显示）</span></div>
              <a-textarea
                v-model="pay.rechargeTips"
                :rows="3" :max-length="240" show-word-limit
                placeholder="例：请扫码向平台支付对应金额，填写订单页上传支付凭证，1个工作日内审核通过后余额到账。"
              />
            </a-tab-pane>

            <!-- ================== Tab2：提现参数 ================== -->
            <a-tab-pane key="withdraw">
              <template #title>
                <span class="tab-title"><IconExport style="color:#ff7d00" /> 提现参数</span>
              </template>

              <!-- 启用开关 + Alert（在同一张卡片内） -->
              <div class="pay-row head-row">
                <div>
                  <div class="row-title">启用提现</div>
                  <div class="row-desc">关闭后客户端「提现」按钮灰掉，不允许提交新的提现申请</div>
                </div>
                <a-switch v-model="pay.withdrawEnabled" />
              </div>

              <a-alert type="info" :show-icon="true" class="pay-alert">
                <template #message>冻结与扣费规则</template>
                <template #description>
                  用户提交提现申请时：<b>先按 amount 冻结余额</b>。后台操作：
                  <span class="chip ok">确定提现</span> → frozen 解冻 amount + 余额扣 <code>fee</code>；
                  <span class="chip warn">驳回</span> → frozen amount <b>原路退回</b> 余额，不扣手续费。
                </template>
              </a-alert>

              <!-- 门槛 3 项 + 费率&预览 双栏（卡片内部） -->
              <div class="pay-divider">参数设置</div>
              <div class="withdraw-two-col">
                <!-- 左：门槛 -->
                <div class="col-block">
                  <div class="col-title">金额门槛</div>
                  <a-form layout="vertical" :label-col-props="{ span: 24 }">
                    <a-form-item label="单笔最低提现（元）">
                      <a-input-number
                        v-model="pay.withdrawMin" :min="0.01" :max="1000000" :precision="2" :step="10"
                        style="width:100%" hide-button prefix="¥"
                      />
                      <div class="hint">低于此值的提现申请会被拦截。</div>
                    </a-form-item>
                    <a-form-item label="单笔最高提现（元）">
                      <a-input-number
                        v-model="pay.withdrawMax" :min="0.01" :max="100000000" :precision="2" :step="1000"
                        style="width:100%" hide-button prefix="¥"
                      />
                      <div class="hint">防止一次提走大额余额。</div>
                    </a-form-item>
                    <a-form-item label="单笔最低手续费（元）">
                      <a-input-number
                        v-model="pay.withdrawFeeMin" :min="0" :max="10000" :precision="2" :step="1"
                        style="width:100%" hide-button prefix="¥"
                      />
                      <div class="hint">0 = 不设最低；一般 1 ~ 2 元。</div>
                    </a-form-item>
                  </a-form>
                </div>

                <!-- 右：费率 + 预览 -->
                <div class="col-block">
                  <div class="col-title">费率 & 实时预览 <a-tag color="orange" style="margin-left:6px">fee = max(amount × rate, feeMin)</a-tag></div>
                  <a-form layout="vertical" :label-col-props="{ span: 24 }">
                    <a-form-item label="手续费费率（0% ~ 10%）">
                      <div class="slider-row">
                        <a-slider
                          v-model="pay.withdrawFeeRate"
                          :min="0" :max="0.1" :step="0.001"
                          :marks="sliderMarks"
                          style="flex:1"
                        />
                        <div class="rate-chip">
                          {{ (pay.withdrawFeeRate * 100).toFixed(1) }}%
                        </div>
                      </div>
                    </a-form-item>
                  </a-form>

                  <div class="preview-box">
                    <div class="preview-title">示例：提现 ¥1,000 时</div>
                    <div class="preview-row">
                      <div>
                        <div class="label">手续费</div>
                        <div class="value fee">¥ {{ sampleFee.toFixed(2) }}</div>
                      </div>
                      <div>
                        <div class="label">到账金额</div>
                        <div class="value ok">¥ {{ (1000 - sampleFee).toFixed(2) }}</div>
                      </div>
                      <div>
                        <div class="label">冻结总额</div>
                        <div class="value">¥ 1,000.00</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </a-tab-pane>
          </a-tabs>

          <!-- 底部操作条（在同一张卡片底部；sticky 贴在视口底部，长内容一滚就看见） -->
          <div class="pay-actions-inner">
            <a-space>
              <a-button type="outline" @click="loadPayConfig">重新加载</a-button>
              <a-button type="primary" status="success" :loading="paySaving" @click="savePayConfig">
                <template #icon><IconCheckCircle /></template>
                保存支付配置
              </a-button>
            </a-space>
          </div>
        </a-card>

        <!-- 二维码大图预览（section 层 Modal，不包在卡片里） -->
        <a-modal
          v-model:visible="qrVisible"
          :title="qrPreviewTitle"
          :footer="false"
          :mask-closable="true"
          width="520"
          @before-close="() => { qrPreviewSrc = '' }"
        >
          <div style="display:flex;justify-content:center">
            <img v-if="qrPreviewSrc" :src="qrPreviewSrc" style="max-width:100%;border-radius:12px;box-shadow:0 6px 20px rgba(0,0,0,.08)" />
          </div>
        </a-modal>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, onMounted, markRaw } from 'vue'
import { Message } from '@arco-design/web-vue'
import { IconImage, IconUserGroup, IconInfoCircle, IconNotification, IconStorage, IconMessage, IconCamera, IconSettings, IconSend, IconQrcode, IconWechatpay, IconExport, IconEye, IconDelete, IconCheckCircle, IconExperiment } from '@arco-design/web-vue/es/icon'
import { adminApi } from '@/api/admin'
import ImageUpload from './ImageUpload.vue'

const activeSection = ref('brand')

const sections = [
  { key: 'brand', title: '品牌', icon: markRaw(IconImage) },
  { key: 'feature', title: '功能开关', icon: markRaw(IconExperiment) },
  { key: 'auth', title: '注册认证', icon: markRaw(IconUserGroup) },
  { key: 'kefu', title: '客服设置', icon: markRaw(IconUserGroup) },
  { key: 'version', title: 'App 版本', icon: markRaw(IconInfoCircle) },
  { key: 'notify', title: '系统公告', icon: markRaw(IconNotification) },
  { key: 'storage', title: '对象存储', icon: markRaw(IconStorage) },
  { key: 'pay', title: '支付配置', icon: markRaw(IconQrcode) },
  { key: 'sms', title: '短信', icon: markRaw(IconMessage) },
  { key: 'trtc', title: '音视频', icon: markRaw(IconCamera) },
  { key: 'jpush', title: '推送', icon: markRaw(IconSend) },
  { key: 'infra', title: '节点', icon: markRaw(IconSettings) }
]

const cfg = ref({ registerOn: true, authMode: 'none' as string, inviteCodeOn: false, captchaOn: false, e2eOn: false })
// 功能开关（默认开启：后台未配置时 sys_config 返回 null，视为开启）
const feature = ref({ walletOn: true, inviteOn: true })
// 客服设置：kefu_config 为整体 JSON 键（{autoAdd, mode, greeting}），读取后解包渲染，保存时整体写回
const kefu = ref({ autoAdd: false, mode: 'round' as string, greeting: '' })
const savingKefu = ref(false)
const brand = ref({ appName: '', brandName: '', appLogo: '', brandLogo: '' })
const version = ref({ appVersion: '', updateLog: '', androidUrl: '', iosUrl: '', hotUpdateUrl: '' })
const sms = ref({ accessKey: '', secret: '', signName: '', templateCode: '' })
const trtc = ref({ appId: '', secretKey: '' })
const jpush = ref({ enabled: false, appKey: '', masterSecret: '', apnsProduction: false })
const minio = ref({ endpoint: '', publicUrl: '', accessKey: '', secretKey: '', bucket: '' })
const infra = ref({ nodeId: '', jwtSecret: '' })
const announcement = ref('')
const misc = ref({ defaultAvatar: '', reservedIds: '' })

// === 支付配置（放在对象存储下的 section） ===
const pay = ref({
  enabled: true,
  receiveWechatQrcodeUrl: '',
  receiveAlipayQrcodeUrl: '',
  receiveBankQrcodeUrl: '',
  receiveBankInfo: { bankName: '', cardNo: '', accountName: '' },
  rechargeTips: '',
  withdrawEnabled: true,
  withdrawMin: 10,
  withdrawMax: 50000,
  withdrawFeeRate: 0,
  withdrawFeeMin: 0
})
const paySaving = ref(false)
const qrVisible = ref(false)
const qrPreviewSrc = ref('')
const qrPreviewTitle = ref('')
const sliderMarks: Record<number, string> = {
  0: '0%', 0.003: '0.3%', 0.005: '0.5%', 0.01: '1%', 0.02: '2%', 0.05: '5%', 0.1: '10%'
}
const sampleFee = computed(() => {
  const raw = 1000 * (pay.value.withdrawFeeRate || 0)
  const min = pay.value.withdrawFeeMin || 0
  return Math.max(min, Math.round(raw * 100) / 100)
})

function openQrPreview(src: string, title: string) {
  if (!src) return
  qrPreviewSrc.value = src
  qrPreviewTitle.value = title
  qrVisible.value = true
}

async function loadPayConfig() {
  try {
    const { data } = await adminApi.payConfigGet()
    if (data?.code !== 0) { Message.error(data?.message || '读取支付配置失败'); return }
    const payload = (data?.data ?? {}) as Record<string, any>
    const { receiveBankInfo, ...rest } = payload
    Object.assign(pay.value, rest)
    if (receiveBankInfo && typeof receiveBankInfo === 'object') {
      Object.assign(pay.value.receiveBankInfo, receiveBankInfo)
    }
  } catch (e: any) {
    Message.error('读取支付配置失败：' + (e?.message || ''))
  }
}

async function savePayConfig() {
  // 校验
  if (pay.value.withdrawMin < 0.01) { Message.warning('提现最低金额必须 > 0'); return }
  if (pay.value.withdrawMax < pay.value.withdrawMin) { Message.warning('提现最高不能小于最低'); return }
  if (pay.value.withdrawFeeRate < 0 || pay.value.withdrawFeeRate > 0.1) { Message.warning('费率需在 0~0.1 之间'); return }
  if (pay.value.withdrawFeeMin < 0) { Message.warning('最低手续费不能为负'); return }
  paySaving.value = true
  try {
    const { enabled, receiveWechatQrcodeUrl, receiveAlipayQrcodeUrl, receiveBankQrcodeUrl, receiveBankInfo, rechargeTips, withdrawEnabled, withdrawMin, withdrawMax, withdrawFeeRate, withdrawFeeMin } = pay.value
    const payload = { enabled, receiveWechatQrcodeUrl, receiveAlipayQrcodeUrl, receiveBankQrcodeUrl, receiveBankInfo, rechargeTips, withdrawEnabled, withdrawMin, withdrawMax, withdrawFeeRate, withdrawFeeMin }
    const { data } = await adminApi.payConfigSet(payload)
    if (data?.code !== 0) { Message.error(data?.message || '保存失败'); return }
    Message.success('支付配置已保存')
    await loadPayConfig()
  } catch (e: any) {
    Message.error('保存支付配置失败：' + (e?.message || ''))
  } finally {
    paySaving.value = false
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
  // 功能开关（null = 未配置 = 默认开启）
  const [w, iv] = await Promise.all(['wallet_enabled', 'invite_feature_enabled'].map((k) => adminApi.configGet(k)))
  feature.value = {
    walletOn: w.data.data === null ? true : !!w.data.data,
    inviteOn: iv.data.data === null ? true : !!iv.data.data
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
  const jpKeys = ['jpush_enabled', 'jpush_app_key', 'jpush_master_secret', 'jpush_apns_production']
  const [je, ja, jm, jp] = await Promise.all(jpKeys.map((k) => adminApi.configGet(k)))
  jpush.value = {
    enabled: !!je.data.data,
    appKey: String(ja.data.data || ''),
    masterSecret: String(jm.data.data || ''),
    apnsProduction: !!jp.data.data
  }
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
  // 客服设置（GET 返回 SysConfigGet 解包后的 {autoAdd, mode, greeting}，未配置时为 null）
  try {
    const kf = await adminApi.configGet('kefu_config')
    const kfVal = (kf.data?.data ?? null) as Record<string, any> | null
    kefu.value = {
      autoAdd: !!kfVal?.autoAdd,
      mode: kfVal?.mode === 'all' ? 'all' : 'round',
      // 后端已兜底默认文案；前端再保险一次，避免首次进入空 textarea 没引导
      greeting: typeof kfVal?.greeting === 'string' ? kfVal.greeting : '你好，我是 {nickname}，很高兴为您服务~'
    }
  } catch { /* 未配置时保持默认 */ }
  const miscKeys = ['default_avatar']
  const [da] = await Promise.all(miscKeys.map((k) => adminApi.configGet(k)))
  misc.value = { defaultAvatar: String(da.data.data || ''), reservedIds: '' }
  const ann = await adminApi.configGet('announcement')
  announcement.value = String(ann.data.data || '')
  // 支付配置也一并拉下来（pay section 一进来就有值，不闪）
  void loadPayConfig()
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
    adminApi.configSet('default_avatar', misc.value.defaultAvatar)
  ])
  Message.success('品牌设置已保存')
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

async function saveJpush() {
  await Promise.all([
    adminApi.configSet('jpush_enabled', jpush.value.enabled),
    adminApi.configSet('jpush_app_key', jpush.value.appKey),
    adminApi.configSet('jpush_master_secret', jpush.value.masterSecret),
    adminApi.configSet('jpush_apns_production', jpush.value.apnsProduction)
  ])
  Message.success('推送配置已保存（服务端 1 分钟内生效）')
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

async function saveKefu() {
  savingKefu.value = true
  try {
    // 整体写回 {autoAdd, mode, greeting}；后端 SysConfigSet 包 {"value": {...}} 存 sys_config
    const { data } = await adminApi.configSet('kefu_config', {
      autoAdd: kefu.value.autoAdd,
      mode: kefu.value.mode,
      greeting: kefu.value.greeting
    })
    if (data.code === 0) Message.success('客服设置已保存')
    else Message.error(data.message)
  } finally {
    savingKefu.value = false
  }
}
</script>

<style scoped>
.config-page { display: flex; gap: var(--app-space-lg); height: 100%; min-height: 600px; }

/* 左侧分区导航 */
.config-nav {
  width: 180px;
  display: flex; flex-direction: column; gap: 4px;
  padding: 12px;
  background: var(--app-bg-card);
  border: 1px solid var(--app-border-2);
  border-radius: var(--app-radius-lg);
  box-shadow: var(--app-shadow-card);
  flex-shrink: 0;
  height: fit-content;
  position: sticky; top: 0;
}
.nav-btn {
  display: flex; align-items: center; gap: 10px;
  width: 100%; padding: 10px 12px;
  background: transparent; border: none;
  border-radius: var(--app-radius-md);
  color: var(--app-text-2);
  font-size: var(--app-font-size-base);
  cursor: pointer; text-align: left;
  transition: background var(--app-transition-base), color var(--app-transition-base);
}
.nav-btn:hover { background: var(--app-border-2); color: var(--app-text-1); }
.nav-btn.active {
  background: var(--app-primary-bg);
  color: var(--app-primary);
  font-weight: var(--app-font-weight-medium);
}
.nav-btn :deep(svg) { width: 18px; height: 18px; flex-shrink: 0; }

/* 右侧内容 */
.config-body { flex: 1; min-width: 0; }
.section { max-width: 780px; }
.section-title { margin: 0 0 6px; font-size: var(--app-font-size-xl); font-weight: var(--app-font-weight-semibold); color: var(--app-text-1); }
.section-desc { margin: 0 0 16px; font-size: var(--app-font-size-sm); color: var(--app-text-3); }
.form-card { border-radius: var(--app-radius-lg); }
.form-card :deep(.arco-form-item-label) { padding-bottom: 6px; font-weight: 500; }
.form-card :deep(.arco-form-item) { margin-bottom: 18px; }
.brand-card :deep(.arco-form-item:last-child) { margin-bottom: 0; }
.form-actions {
  display: flex; align-items: center; justify-content: flex-start;
  padding-top: 8px;
}

/* ================= 支付配置 section 样式（**单卡片**包住两个 Tab 全部内容） ================= */
.pay-section { max-width: 1180px; }
.pay-tabs :deep(.arco-tabs-header) { margin: 0 0 20px; }
.tab-title { display: inline-flex; align-items: center; gap: 6px; font-weight: 600; }

/* 整张大卡片：圆角 + 投影 + 内边距更大，让用户一眼看到"一张卡片" */
.pay-card {
  border-radius: 18px;
  background: #fff;
  box-shadow:
    0 1px 2px rgba(0,0,0,0.04),
    0 6px 18px rgba(15,20,40,0.05),
    0 18px 50px rgba(15,20,40,0.04);
  overflow: hidden;
}
.pay-card :deep(.arco-card-body) { padding: 24px 28px 0; }

/* 行：标题 + 开关 */
.pay-row { display: flex; align-items: flex-start; gap: 20px; }
.pay-row.head-row {
  padding: 14px 18px;
  border-radius: 14px;
  background: linear-gradient(135deg, #f4f7ff 0%, #ffffff 100%);
  border: 1px solid #e2e9ff;
  margin-bottom: 20px;
}
.pay-row .row-title { font-size: 15px; font-weight: 600; color: var(--app-text-1); margin-bottom: 4px; }
.pay-row .row-desc  { font-size: 12.5px; color: var(--app-text-3); }
.pay-row > :last-child { margin-left: auto; }

/* 分隔标题（卡片内部分段用，替代之前丑 a-divider） */
.pay-divider {
  display: flex; align-items: center;
  margin: 22px 0 14px;
  color: var(--app-text-2);
  font-weight: 600;
  font-size: 14px;
  position: relative;
}
.pay-divider::before {
  content: "";
  width: 3px; height: 14px;
  background: linear-gradient(180deg, #165dff, #6aa0ff);
  border-radius: 3px;
  margin-right: 10px;
  box-shadow: 0 1px 3px rgba(22,93,255,.35);
}
.pay-divider .d-sub { font-weight: 400; font-size: 12px; color: var(--app-text-3); margin-left: 6px; }

/* 收款码 3 列：卡片**内部** 3 个通道盒（不用 a-card 套，就盒子+品牌色左边条） */
.channels-grid {
  display: grid; grid-template-columns: repeat(3, 1fr);
  gap: 18px;
}
@media (max-width: 1100px) { .channels-grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 720px)  { .channels-grid { grid-template-columns: 1fr; } }

.ch {
  border-radius: 16px;
  background: #fafbfc;
  border: 1px solid var(--app-border-2);
  padding: 16px;
  display: flex; flex-direction: column;
  transition: all .2s ease;
  position: relative;
  overflow: hidden;
}
.ch::before {
  content: ""; position: absolute; left: 0; top: 0; bottom: 0; width: 4px;
}
.ch.wechat::before   { background: linear-gradient(180deg, #07c160, #63e09b); }
.ch.alipay::before   { background: linear-gradient(180deg, #1677ff, #76aaff); }
.ch.bank::before     { background: linear-gradient(180deg, #ff7d00, #ffc285); }
.ch:hover {
  background: #fff;
  transform: translateY(-2px);
  box-shadow: 0 8px 22px rgba(0,0,0,0.06);
}
.ch-head { display: flex; align-items: center; gap: 8px; margin-bottom: 12px; padding-left: 4px; }
.ch-brand {
  display: inline-flex; align-items: center; gap: 6px;
  font-weight: 700; color: #fff; font-size: 13.5px;
  padding: 3px 10px; border-radius: 8px;
}
.ch.wechat .ch-brand { background: linear-gradient(135deg, #07c160,#2ed573); }
.ch.alipay .ch-brand { background: linear-gradient(135deg, #1677ff,#3b8cff); }
.ch.bank   .ch-brand { background: linear-gradient(135deg, #ff7d00,#ff9d3b); }

.ch-main { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 12px; }
.ch-ops  { display: flex; gap: 8px; }

/* 提现提示卡 */
.pay-alert { border-radius: 12px; margin-bottom: 0; }
.chip {
  display: inline-block; padding: 1px 8px; border-radius: 999px;
  font-size: 12px; font-weight: 500; margin: 0 4px;
}
.chip.ok   { background: #e8f9ef; color: #07c160; border: 1px solid #bef0cf; }
.chip.warn { background: #fff3e6; color: #ff7d00; border: 1px solid #ffd7af; }

/* 提现 2 栏：门槛 左 / 费率+预览 右 */
.withdraw-two-col {
  display: grid; grid-template-columns: 1fr 1fr; gap: 18px;
  margin-top: 4px;
}
@media (max-width: 900px) { .withdraw-two-col { grid-template-columns: 1fr; } }
.col-block {
  border-radius: 14px;
  background: #fafbfc;
  border: 1px solid var(--app-border-2);
  padding: 16px 18px;
}
.col-title {
  font-weight: 600;
  padding: 4px 0 12px;
  margin-bottom: 10px;
  border-bottom: 1px dashed var(--app-border-2);
  display: flex; align-items: center;
}
.muted { color: var(--app-text-3); font-size: 12px; }

/* 提现费率滑条 */
.slider-row { display: flex; align-items: center; gap: 16px; }
.rate-chip {
  min-width: 72px; text-align: center;
  padding: 6px 10px; border-radius: 10px;
  background: linear-gradient(135deg, #fff6ee, #ffe6d1);
  color: #ff7d00; font-weight: 700; border: 1px solid #ffd0a6;
  font-size: 14px;
}

/* 预览卡 */
.preview-box {
  margin-top: 8px; padding: 14px 16px; border-radius: 14px;
  background: linear-gradient(135deg, #f4f7ff 0%, #ffffff 60%, #fff3ed 100%);
  border: 1px solid #dfe6ff;
}
.preview-title { font-size: 12.5px; color: var(--app-text-3); margin-bottom: 10px; letter-spacing: .5px; }
.preview-row { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }
.preview-row .label { font-size: 12px; color: var(--app-text-3); margin-bottom: 6px; }
.preview-row .value { font-size: 20px; font-weight: 700; color: var(--app-text-1); }
.preview-row .value.fee { color: #f53f3f; }
.preview-row .value.ok  { color: #07c160; }

/* 卡片**内部**的底部保存条（sticky 视口底部，滚一屏就能看见） */
.pay-actions-inner {
  margin: 20px -28px 0;
  padding: 14px 28px;
  border-top: 1px solid var(--app-border-2);
  background: #fcfdff;
  display: flex; justify-content: flex-end;
  position: sticky; bottom: 0; z-index: 2;
  backdrop-filter: blur(6px);
}
.hint { color: var(--app-text-3); font-size: 12px; margin-top: 6px; }
</style>
