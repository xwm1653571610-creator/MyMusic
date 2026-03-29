const express = require('express');
const router = express.Router();
const db = require('../db');
const upload = require('../middlewares/upload');

// GET /api/songs - 获取歌曲列表
router.get('/', async (req, res) => {
    try {
        const [rows] = await db.query('SELECT * FROM songs ORDER BY created_at DESC');
        res.json({ code: 200, message: '获取歌曲列表成功', data: rows });
    } catch (error) {
        console.error('获取歌曲列表失败:', error);
        res.status(500).json({ code: 500, message: '服务器内部错误', error: error.message });
    }
});

// GET /api/songs/search - 搜索歌曲
router.get('/search', async (req, res) => {
    try {
        const { keyword } = req.query;
        if (!keyword) {
            return res.status(400).json({ code: 400, message: '搜索关键词不能为空' });
        }
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
router.get('/:id', async (req, res) => {
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
// (由于目前上传可以被全员使用，暂不强绑定 verifyToken，如果需要可以在 app.js 挂载时加)
router.post('/upload', upload.fields([{ name: 'audio', maxCount: 1 }, { name: 'cover', maxCount: 1 }]), async (req, res) => {
    try {
        const { title, artist, album } = req.body;
        
        if (!title || !artist || !req.files || !req.files['audio']) {
            return res.status(400).json({ code: 400, message: '歌名、歌手和音频文件不能为空' });
        }

        const audioFile = req.files['audio'][0];
        const coverFile = req.files['cover'] ? req.files['cover'][0] : null;

        const protocol = req.protocol;
        const host = req.get('host');
        const audioUrl = `${protocol}://${host}/static/audio/${audioFile.filename}`;
        const coverUrl = coverFile ? `${protocol}://${host}/static/covers/${coverFile.filename}` : null;

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

module.exports = router;
