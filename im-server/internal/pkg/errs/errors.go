package errs

// 统一错误码：服务端只返回 code，界面文案由客户端按语言渲染
var (
	Success      = &Err{Code: 0, Msg: "ok"}
	ParamError   = &Err{Code: 1001, Msg: "参数错误"}
	Unauthorized = &Err{Code: 1002, Msg: "未登录或登录过期"}
	Forbidden    = &Err{Code: 1003, Msg: "无权限"}

	AccountExists = &Err{Code: 2001, Msg: "账号已存在"}
	CodeInvalid   = &Err{Code: 2002, Msg: "验证码错误或过期"}
	InviteInvalid = &Err{Code: 2003, Msg: "邀请码无效"}
	RegisterOff   = &Err{Code: 2004, Msg: "注册已关闭"}
	LoginFailed   = &Err{Code: 2005, Msg: "账号或密码错误"}

	FriendReqNotFound = &Err{Code: 3001, Msg: "好友申请不存在"}

	ConvNotFound = &Err{Code: 4001, Msg: "会话不存在或非成员"}
	GroupFull    = &Err{Code: 4002, Msg: "群人数已达上限"}
	RecallDenied = &Err{Code: 4003, Msg: "撤回超时或无权限"}

	FileTooLarge = &Err{Code: 5001, Msg: "文件过大或类型不允许"}

	CallRoomNotFound = &Err{Code: 6001, Msg: "通话房间不存在"}

	RateLimited = &Err{Code: 7001, Msg: "操作过于频繁"}
)

type Err struct {
	Code int    `json:"code"`
	Msg  string `json:"message"`
}

func (e *Err) Error() string { return e.Msg }
