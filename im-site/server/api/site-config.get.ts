export default defineEventHandler(async () => {
  const d = getDb()
  const r = d.prepare(`SELECT
    site_title, site_description, site_keywords, logo, contact_telegram, h5_demo_url,
    contact_wechat, contact_qq, contact_phone, contact_email,
    price_standard_usdt, price_professional_usdt, price_enterprise_text, price_period,
    price_standard_note, price_professional_note, price_enterprise_note,
    android_download_url, admin_panel_url, pc_client_url
    FROM site_config WHERE id = 1`).get() as any
  return {
    code: 0,
    data: {
      siteTitle: r.site_title,
      siteDescription: r.site_description,
      siteKeywords: r.site_keywords,
      logo: r.logo,
      contactTelegram: r.contact_telegram,
      contactWechat: r.contact_wechat || '',
      contactQq: r.contact_qq || '',
      contactPhone: r.contact_phone || '',
      contactEmail: r.contact_email || '',
      h5DemoUrl: r.h5_demo_url,
      androidDownloadUrl: r.android_download_url || '',
      adminPanelUrl: r.admin_panel_url || '',
      pcClientUrl: r.pc_client_url || '',
      pricing: {
        period: r.price_period,
        standard:   { usdt: Number(r.price_standard_usdt),    note: r.price_standard_note },
        professional:{ usdt: Number(r.price_professional_usdt),note: r.price_professional_note },
        enterprise: { text: r.price_enterprise_text,              note: r.price_enterprise_note },
      },
    },
  }
})
