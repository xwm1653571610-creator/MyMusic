const express = require('express');
const router = express.Router();
const db = require('../db');

// POST /api/favorites — 切换收藏（存储网易云歌曲元信息）
router.post('/', async (req, res) => {
    try {
        const { user_id, song_id, title, artist, cover_url } = req.body;
        if (!user_id || !song_id) {
            return res.status(400).json({ code: 400, message: 'user_id 和 song_id 不能为空' });
        }

        const [existing] = await db.query('SELECT id FROM favorites WHERE user_id = ? AND song_id = ?', [user_id, song_id]);
        if (existing.length > 0) {
            await db.query('DELETE FROM favorites WHERE user_id = ? AND song_id = ?', [user_id, song_id]);
            res.json({ code: 200, message: '取消收藏成功', data: { isFavorite: false } });
        } else {
            await db.query(
                'INSERT INTO favorites (user_id, song_id, title, artist, cover_url) VALUES (?, ?, ?, ?, ?)',
                [user_id, song_id, title || '', artist || '', cover_url || '']
            );
            res.json({ code: 200, message: '收藏成功', data: { isFavorite: true } });
        }
    } catch (error) {
        res.status(500).json({ code: 500, message: '服务器内部错误', error: error.message });
    }
});

// GET /api/favorites/:user_id — 获取用户收藏列表（直接返回冗余的歌曲信息）
router.get('/:user_id', async (req, res) => {
    try {
        const { user_id } = req.params;
        const [rows] = await db.query(
            'SELECT song_id as id, title, artist, cover_url FROM favorites WHERE user_id = ? ORDER BY created_at DESC',
            [user_id]
        );
        res.json({ code: 200, message: '获取收藏列表成功', data: rows });
    } catch (error) {
        res.status(500).json({ code: 500, message: '服务器内部错误', error: error.message });
    }
});

module.exports = router;
