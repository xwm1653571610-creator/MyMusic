const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();

// 中间件配置
app.use(cors()); // 允许跨域
app.use(express.json()); // 解析 JSON 格式的请求体

// 静态文件代理
app.use('/static', express.static('public'));

// --------------------------------------------------
// API 路由网关
// --------------------------------------------------
const usersRouter = require('./routes/users');
const songsRouter = require('./routes/songs');
const favoritesRouter = require('./routes/favorites');
const verifyToken = require('./middlewares/auth');

// 挂载各业务模块路由
app.use('/api/users', usersRouter);

// 歌曲的浏览是公开的，但如果是更深层的业务可以考虑加 verifyToken
app.use('/api/songs', songsRouter);

// 所有对 Favorites 的请求严格要求鉴权
app.use('/api/favorites', verifyToken, favoritesRouter);

// --------------------------------------------------
// 启动服务器
// --------------------------------------------------
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🎵 音乐后端服务 (MVC重构版) 已启动，运行在 http://localhost:${PORT}`);
});