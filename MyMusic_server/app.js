const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const db = require('./db');
require('dotenv').config();

const app = express();

// 中间件配置
app.use(cors()); // 允许跨域
app.use(express.json()); // 解析 JSON 格式的请求体

// 托管静态文件，访问路径前面加上 /static
// 例如：访问 http://localhost:3000/static/audio/yequ.mp3 就能播放音乐
app.use('/static', express.static('public'));

// 配置 multer 存储策略
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        if (file.fieldname === 'audio') {
            cb(null, 'public/audio');
        } else if (file.fieldname === 'cover') {
            cb(null, 'public/covers');
        } else {
            cb(null, 'public');
        }
    },
    filename: function (req, file, cb) {
        // 使用时间戳防止文件重名
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + path.extname(file.originalname));
    }
});
const upload = multer({ storage: storage });


// --------------------------------------------------
// API 路由部分
// --------------------------------------------------

// GET /api/songs - 获取歌曲列表
app.get('/api/songs', async (req, res) => {
    try {
        // 执行 SQL 查询
        const [rows] = await db.query('SELECT * FROM songs ORDER BY created_at DESC');
        
        // 返回成功响应
        res.json({
            code: 200,
            message: '获取歌曲列表成功',
            data: rows
        });
    } catch (error) {
        console.error('获取歌曲列表失败:', error);
        // 返回错误响应
        res.status(500).json({
            code: 500,
            message: '服务器内部错误',
            error: error.message
        });
    }
});


// GET /api/songs/search - 搜索歌曲
app.get('/api/songs/search', async (req, res) => {
    try {
        const { keyword } = req.query;
        if (!keyword) {
            return res.status(400).json({ code: 400, message: '搜索关键词不能为空' });
        }
        // 使用模糊查询
        const searchQuery = `%${keyword}%`;
        const [rows] = await db.query(
            'SELECT * FROM songs WHERE title LIKE ? OR artist LIKE ? ORDER BY created_at DESC', 
            [searchQuery, searchQuery]
        );
        res.json({ code: 200, message: '搜索成功', data: rows });
    } catch (error) {
        res.status(500).json({ code: 500, message: '服务器错误', error: error.message });
    }
});

// GET /api/songs/:id - 获取单首歌曲详情
app.get('/api/songs/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const [rows] = await db.query('SELECT * FROM songs WHERE id = ?', [id]);
        if (rows.length === 0) {
            return res.status(404).json({ code: 404, message: '歌曲不存在' });
        }
        res.json({ code: 200, message: '获取成功', data: rows[0] });
    } catch (error) {
        res.status(500).json({ code: 500, message: '服务器错误', error: error.message });
    }
});


// POST /api/songs/upload - 上传音乐和封面
app.post('/api/songs/upload', upload.fields([{ name: 'audio', maxCount: 1 }, { name: 'cover', maxCount: 1 }]), async (req, res) => {
    try {
        const { title, artist, album } = req.body;
        
        // 校验必填字段
        if (!title || !artist || !req.files || !req.files['audio']) {
            return res.status(400).json({ code: 400, message: '歌名、歌手和音频文件不能为空' });
        }

        const audioFile = req.files['audio'][0];
        const coverFile = req.files['cover'] ? req.files['cover'][0] : null;

        // 拼接网络访问的完整 URL
        const protocol = req.protocol;
        const host = req.get('host');
        const audioUrl = `${protocol}://${host}/static/audio/${audioFile.filename}`;
        const coverUrl = coverFile ? `${protocol}://${host}/static/covers/${coverFile.filename}` : null;

        // 插入数据库
        const [result] = await db.query(
            'INSERT INTO songs (title, artist, album, audio_url, cover_url) VALUES (?, ?, ?, ?, ?)',
            [title, artist, album || null, audioUrl, coverUrl]
        );

        res.json({
            code: 200,
            message: '上传成功',
            data: {
                id: result.insertId,
                title,
                artist,
                album,
                audio_url: audioUrl,
                cover_url: coverUrl
            }
        });
    } catch (error) {
        console.error('上传失败:', error);
        res.status(500).json({ code: 500, message: '服务器内部错误', error: error.message });
    }
});


// POST /api/users/register - 用户注册
app.post('/api/users/register', async (req, res) => {
    try {
        const { username, password } = req.body;
        if (!username || !password) {
            return res.status(400).json({ code: 400, message: '用户名和密码不能为空' });
        }

        // 检查用户名是否已存在
        const [existing] = await db.query('SELECT id FROM users WHERE username = ?', [username]);
        if (existing.length > 0) {
            return res.status(409).json({ code: 409, message: '用户名已被注册' });
        }

        // 密码加密 (加盐哈希)
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        // 插入数据库
        const [result] = await db.query(
            'INSERT INTO users (username, password) VALUES (?, ?)', 
            [username, hashedPassword]
        );

        res.json({ code: 200, message: '注册成功', data: { userId: result.insertId } });
    } catch (error) {
        res.status(500).json({ code: 500, message: '服务器错误', error: error.message });
    }
});

// POST /api/users/login - 用户登录
app.post('/api/users/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        // 查找用户
        const [users] = await db.query('SELECT * FROM users WHERE username = ?', [username]);
        if (users.length === 0) {
            return res.status(401).json({ code: 401, message: '用户名或密码错误' });
        }

        const user = users[0];

        // 校验密码
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(401).json({ code: 401, message: '用户名或密码错误' });
        }

        // 生成 JWT Token (有效期7天)
        const token = jwt.sign(
            { id: user.id, username: user.username }, 
            process.env.JWT_SECRET, 
            { expiresIn: '7d' }
        );

        res.json({ 
            code: 200, 
            message: '登录成功', 
            data: { 
                token, 
                user: { id: user.id, username: user.username, avatar_url: user.avatar_url }
            } 
        });
    } catch (error) {
        res.status(500).json({ code: 500, message: '服务器错误', error: error.message });
    }
});

// --------------------------------------------------
// 启动服务器
// --------------------------------------------------
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🎵 音乐后端服务已启动，运行在 http://localhost:${PORT}`);
});