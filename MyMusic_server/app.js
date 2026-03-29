const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();

// 中间件
app.use(cors());
app.use(express.json());
app.use('/static', express.static('public'));

// 路由挂载
const usersRouter = require('./routes/users');
const favoritesRouter = require('./routes/favorites');
const neteaseRouter = require('./routes/netease');

app.use('/api/users', usersRouter);
app.use('/api/favorites', favoritesRouter);
app.use('/api/music', neteaseRouter);  // 网易云音乐代理

// 启动
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🎵 MyMusic 后端已启动: http://localhost:${PORT}`);
    console.log(`   📡 网易云代理: /api/music/search, /api/music/url, /api/music/hot`);
    console.log(`   👤 用户服务:   /api/users/login, /api/users/register`);
    console.log(`   ❤️  收藏服务:   /api/favorites`);
});