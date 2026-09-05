<template>
  <footer class="app-footer">
    <div class="footer-inner container">
      <div class="footer-grid">
        <!-- Column 1: 产品 -->
        <div class="footer-col">
          <h3 class="footer-heading">产品</h3>
          <ul class="footer-list">
            <li>
              <NuxtLink to="/features" class="footer-link">功能</NuxtLink>
            </li>
            <li>
              <NuxtLink to="/pricing" class="footer-link">定价</NuxtLink>
            </li>
            <li>
              <NuxtLink to="/demo" class="footer-link">Demo体验</NuxtLink>
            </li>
            <li>
              <NuxtLink to="/faq" class="footer-link">帮助</NuxtLink>
            </li>
          </ul>
        </div>

        <!-- Column 2: 资源 -->
        <div class="footer-col">
          <h3 class="footer-heading">资源</h3>
          <ul class="footer-list">
            <li>
              <NuxtLink to="/docs" class="footer-link">技术文档</NuxtLink>
            </li>
            <li>
              <NuxtLink to="/faq" class="footer-link">FAQ</NuxtLink>
            </li>
            <li>
              <NuxtLink to="/changelog" class="footer-link">更新日志</NuxtLink>
            </li>
            <li>
              <NuxtLink to="/api-docs" class="footer-link">API文档</NuxtLink>
            </li>
          </ul>
        </div>

        <!-- Column 3: 公司 -->
        <div class="footer-col">
          <h3 class="footer-heading">公司</h3>
          <ul class="footer-list">
            <li>
              <NuxtLink to="/about" class="footer-link">关于我们</NuxtLink>
            </li>
            <li>
              <NuxtLink to="/contact" class="footer-link">联系方式</NuxtLink>
            </li>
            <li>
              <NuxtLink to="/custom-development" class="footer-link">定制开发</NuxtLink>
            </li>
            <li>
              <NuxtLink to="/privacy" class="footer-link">隐私协议</NuxtLink>
            </li>
            <li>
              <NuxtLink to="/stress-test" class="footer-link">压力测试报告</NuxtLink>
            </li>
          </ul>
        </div>

        <!-- Column 4: Newsletter -->
        <div class="footer-col footer-col-wide">
          <h3 class="footer-heading">订阅资讯</h3>
          <p class="footer-newsletter-text">
            订阅我们的产品更新与行业资讯，第一时间获取最新动态。
          </p>
          <form class="newsletter-form" @submit.prevent="handleSubscribe">
            <input
              v-model="email"
              type="email"
              class="newsletter-input"
              placeholder="输入您的邮箱"
              required
              aria-label="Email address"
            />
            <button type="submit" class="newsletter-btn">订阅</button>
          </form>
          <p v-if="subscribed" class="newsletter-success">
            订阅成功，感谢关注！
          </p>
        </div>
      </div>
    </div>

    <!-- Bottom bar -->
    <div class="footer-bottom">
      <div class="container bottom-inner">
        <div class="bottom-left">
          <p class="copyright">© 2026 ChatPulse. All rights reserved.</p>
          <NuxtLink to="/quote" class="footer-link-sm">获取报价单</NuxtLink>
          <NuxtLink to="/stress-test" class="footer-link-sm">压力测试报告</NuxtLink>
          <NuxtLink to="/privacy" class="footer-link-sm">隐私协议</NuxtLink>
        </div>
        <div class="social-icons" aria-label="Social links">
          <a
            href="https://github.com"
            class="social-link"
            target="_blank"
            rel="noopener noreferrer"
            aria-label="GitHub"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
              <path
                d="M12 .5C5.37.5 0 5.87 0 12.5c0 5.3 3.44 9.8 8.21 11.39.6.11.82-.26.82-.58 0-.29-.01-1.04-.02-2.05-3.34.73-4.04-1.61-4.04-1.61-.55-1.39-1.34-1.76-1.34-1.76-1.09-.75.08-.73.08-.73 1.21.09 1.85 1.24 1.85 1.24 1.07 1.84 2.81 1.31 3.5 1 .11-.78.42-1.31.76-1.61-2.67-.3-5.47-1.34-5.47-5.96 0-1.32.47-2.39 1.24-3.23-.12-.3-.54-1.52.12-3.17 0 0 1.01-.32 3.3 1.23a11.5 11.5 0 0 1 6 0c2.29-1.55 3.3-1.23 3.3-1.23.66 1.65.24 2.87.12 3.17.77.84 1.24 1.91 1.24 3.23 0 4.63-2.81 5.65-5.49 5.95.43.37.81 1.1.81 2.22 0 1.6-.01 2.89-.01 3.29 0 .32.22.7.83.58A12.01 12.01 0 0 0 24 12.5C24 5.87 18.63.5 12 .5z"
              />
            </svg>
          </a>
          <a
            href="#"
            class="social-link"
            aria-label="WeChat"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
              <path
                d="M8.69 2C4.27 2 .69 5.1.69 8.92c0 2.2 1.2 4.16 3.1 5.47l-.77 2.36 2.74-1.38c.97.27 1.97.42 3.01.42.27 0 .53-.01.79-.04-.17-.55-.27-1.13-.27-1.73 0-3.6 3.1-6.52 6.92-6.52.24 0 .47.01.7.04-.52-3.1-3.66-5.55-7.5-5.55h.28zm-2.4 3.74a.9.9 0 1 1 0 1.8.9.9 0 0 1 0-1.8zm5.41 0a.9.9 0 1 1 0 1.8.9.9 0 0 1 0-1.8z"
              />
              <path
                d="M16.9 9.46c-3.27 0-5.92 2.42-5.92 5.4 0 3 2.65 5.42 5.92 5.42.79 0 1.55-.14 2.25-.4l2.04 1.02-.55-1.69c1.4-.99 2.27-2.5 2.27-4.35 0-2.98-2.65-5.4-5.91-5.4h-.1zm-1.97 3.04a.74.74 0 1 1 0 1.48.74.74 0 0 1 0-1.48zm3.94 0a.74.74 0 1 1 0 1.48.74.74 0 0 1 0-1.48z"
              />
            </svg>
          </a>
          <a
            href="mailto:hello@chatpulse.cn"
            class="social-link"
            aria-label="Email"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
              <rect x="2" y="4" width="20" height="16" rx="2" />
              <path d="m22 7-10 6L2 7" />
            </svg>
          </a>
        </div>
      </div>
    </div>
  </footer>
</template>

<script setup>
import { ref } from 'vue'

const email = ref('')
const subscribed = ref(false)

const handleSubscribe = () => {
  if (!email.value) return
  // Front-end placeholder: integrate with backend/API later.
  subscribed.value = true
  email.value = ''
  setTimeout(() => {
    subscribed.value = false
  }, 4000)
}
</script>

<style scoped>
.app-footer {
  background: #1a1a2e;
  color: #c9cdd4;
  padding: 48px 0 0;
}

.footer-inner {
  padding-bottom: 32px;
}

.footer-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 40px;
}

.footer-col {
  min-width: 0;
}

.footer-heading {
  color: #ffffff;
  font-size: 16px;
  font-weight: 700;
  margin-bottom: 18px;
  letter-spacing: .2px;
}

.footer-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.footer-link {
  color: #c9cdd4;
  font-size: 14px;
  text-decoration: none;
  transition: color .2s ease;
}

.footer-link:hover {
  color: #ffffff;
}

/* Newsletter */
.footer-newsletter-text {
  font-size: 14px;
  color: #c9cdd4;
  line-height: 1.6;
  margin-bottom: 16px;
}

.newsletter-form {
  display: flex;
  gap: 8px;
}

.newsletter-input {
  flex: 1;
  min-width: 0;
  padding: 10px 14px;
  font-size: 14px;
  color: #ffffff;
  background: rgba(255, 255, 255, .06);
  border: 1px solid rgba(255, 255, 255, .15);
  border-radius: 8px;
  outline: none;
  transition: border-color .2s ease, background .2s ease;
}

.newsletter-input::placeholder {
  color: #8a8d96;
}

.newsletter-input:focus {
  border-color: #4080ff;
  background: rgba(255, 255, 255, .1);
}

.newsletter-btn {
  flex-shrink: 0;
  padding: 10px 20px;
  font-size: 14px;
  font-weight: 600;
  color: #ffffff;
  background: linear-gradient(135deg, #165dff 0%, #4080ff 100%);
  border: none;
  border-radius: 8px;
  cursor: pointer;
  transition: transform .2s ease, box-shadow .2s ease;
}

.newsletter-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 16px rgba(22, 93, 255, .35);
}

.newsletter-success {
  margin-top: 10px;
  font-size: 13px;
  color: #23c343;
}

/* Bottom bar */
.footer-bottom {
  border-top: 1px solid rgba(255, 255, 255, .08);
  padding: 20px 0;
}

.bottom-inner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}

.bottom-left {
  display: flex;
  align-items: center;
  gap: 16px;
  flex-wrap: wrap;
}

.copyright {
  font-size: 13px;
  color: #8a8d96;
  margin: 0;
}

.footer-link-sm {
  font-size: 13px;
  color: #8a8d96;
  transition: color .2s;
}
.footer-link-sm:hover {
  color: #fff;
}

.social-icons {
  display: flex;
  align-items: center;
  gap: 8px;
}

.social-link {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  color: #c9cdd4;
  background: rgba(255, 255, 255, .05);
  border-radius: 8px;
  text-decoration: none;
  transition: color .2s ease, background .2s ease, transform .2s ease;
}

.social-link:hover {
  color: #ffffff;
  background: rgba(255, 255, 255, .12);
  transform: translateY(-2px);
}

/* Responsive: stack columns vertically */
@media (max-width: 860px) {
  .footer-grid {
    grid-template-columns: repeat(2, 1fr);
    gap: 32px;
  }
  .footer-col-wide {
    grid-column: 1 / -1;
  }
}

@media (max-width: 560px) {
  .footer-grid {
    grid-template-columns: 1fr;
    gap: 28px;
  }
  .footer-col-wide {
    grid-column: auto;
  }
  .bottom-inner {
    justify-content: center;
    text-align: center;
    flex-direction: column;
    gap: 12px;
  }
  .newsletter-form {
    flex-direction: column;
  }
  .newsletter-btn {
    width: 100%;
  }
}
</style>
