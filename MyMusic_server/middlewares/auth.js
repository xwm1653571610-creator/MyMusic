const jwt = require('jsonwebtoken');

function verifyToken(req, res, next) {
    // 允许通过 Header 或者 Query 传 token
    const token = req.headers.authorization?.split(' ')[1] || req.query.token || req.body.token;

    if (!token) {
        return res.status(401).json({ code: 401, message: '未提供访问令牌，拒绝访问！' });
    }

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded; // 将解析后的用户信息挂载到请求体
        next(); // 放行
    } catch (err) {
        console.error('令牌校验失败:', err.message);
        return res.status(401).json({ code: 401, message: '登录已过期或凭证无效，请重新登录' });
    }
}

module.exports = verifyToken;
