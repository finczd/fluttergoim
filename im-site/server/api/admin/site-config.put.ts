export default defineEventHandler(async (event) => {
  requireAdmin(event)
  const body = await readBody(event)
  const d = getDb()
  const patch: any = {}
  if (body.siteTitle !== undefined) patch.site_title = body.siteTitle
  if (body.siteDescription !== undefined) patch.site_description = body.siteDescription
  if (body.siteKeywords !== undefined) patch.site_keywords = body.siteKeywords
  if (body.logo !== undefined) patch.logo = body.logo
  if (body.contactTelegram !== undefined) patch.contact_telegram = body.contactTelegram
  if (body.contactWechat !== undefined) patch.contact_wechat = String(body.contactWechat)
  if (body.contactQq !== undefined) patch.contact_qq = String(body.contactQq)
  if (body.contactPhone !== undefined) patch.contact_phone = String(body.contactPhone)
  if (body.contactEmail !== undefined) patch.contact_email = String(body.contactEmail)
  if (body.h5DemoUrl !== undefined) patch.h5_demo_url = body.h5DemoUrl
  if (body.androidDownloadUrl !== undefined) patch.android_download_url = String(body.androidDownloadUrl)
  if (body.iosDownloadUrl !== undefined) patch.ios_download_url = String(body.iosDownloadUrl)
  if (body.iosSelfSignGuide !== undefined) patch.ios_self_sign_guide = String(body.iosSelfSignGuide)
  if (body.adminPanelUrl !== undefined) patch.admin_panel_url = String(body.adminPanelUrl)
  if (body.pcClientUrl !== undefined) patch.pc_client_url = String(body.pcClientUrl)

  // 定价（USDT）
  if (body.pricePeriod !== undefined) patch.price_period = String(body.pricePeriod)
  if (body.priceStandardUsdt !== undefined) {
    const v = Number(body.priceStandardUsdt)
    patch.price_standard_usdt = isFinite(v) && v >= 0 ? v : 0
  }
  if (body.priceProfessionalUsdt !== undefined) {
    const v = Number(body.priceProfessionalUsdt)
    patch.price_professional_usdt = isFinite(v) && v >= 0 ? v : 0
  }
  if (body.priceEnterpriseText !== undefined) patch.price_enterprise_text = String(body.priceEnterpriseText)
  if (body.priceStandardNote !== undefined) patch.price_standard_note = String(body.priceStandardNote)
  if (body.priceProfessionalNote !== undefined) patch.price_professional_note = String(body.priceProfessionalNote)
  if (body.priceEnterpriseNote !== undefined) patch.price_enterprise_note = String(body.priceEnterpriseNote)

  if (Object.keys(patch).length) {
    const sets = Object.keys(patch).map(k => `${k} = ?`).join(', ')
    d.prepare(`UPDATE site_config SET ${sets} WHERE id = 1`).run(...Object.values(patch))
  }
  const u = d.prepare(`SELECT site_title,site_description,site_keywords,logo,contact_telegram,contact_wechat,contact_qq,contact_phone,contact_email,h5_demo_url,
    price_standard_usdt,price_professional_usdt,price_enterprise_text,price_period,
    price_standard_note,price_professional_note,price_enterprise_note,
    android_download_url,ios_download_url,ios_self_sign_guide,admin_panel_url,pc_client_url
    FROM site_config WHERE id=1`).get() as any
  return {
    code: 0, message: '保存成功',
    data: {
      siteTitle: u.site_title, siteDescription: u.site_description, siteKeywords: u.site_keywords,
      logo: u.logo, contactTelegram: u.contact_telegram,
      contactWechat: u.contact_wechat || '', contactQq: u.contact_qq || '',
      contactPhone: u.contact_phone || '', contactEmail: u.contact_email || '',
      h5DemoUrl: u.h5_demo_url,
      androidDownloadUrl: u.android_download_url || '',
      iosDownloadUrl: u.ios_download_url || '',
      iosSelfSignGuide: u.ios_self_sign_guide || '请自行签名安装测试',
      adminPanelUrl: u.admin_panel_url || '',
      pcClientUrl: u.pc_client_url || '',
      pricing: {
        period: u.price_period,
        standard:   { usdt: Number(u.price_standard_usdt),    note: u.price_standard_note },
        professional:{ usdt: Number(u.price_professional_usdt),note: u.price_professional_note },
        enterprise: { text: u.price_enterprise_text,              note: u.price_enterprise_note },
      },
    },
  }
})
