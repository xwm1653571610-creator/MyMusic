const express = require('express');
const router = express.Router();
const { cloudsearch, song_url_v1, personalized_newsong, song_detail } = require('NeteaseCloudMusicApi');

// GET /api/music/search?keyword=xxx — 搜索歌曲
router.get('/search', async (req, res) => {
    try {
        const { keyword, limit } = req.query;
        if (!keyword) {
            return res.status(400).json({ code: 400, message: '搜索关键词不能为空' });
        }

        const result = await cloudsearch({
            keywords: keyword,
            type: 1,
            limit: parseInt(limit) || 30
        });

        const songs = (result.body.result.songs || []).map(song => ({
            id: song.id,
            title: song.name,
            artist: song.ar.map(a => a.name).join(' / '),
            album: song.al ? song.al.name : '',
            cover_url: song.al ? song.al.picUrl : '',
            duration: song.dt || 0
        }));

        res.json({ code: 200, message: '搜索成功', data: songs });
    } catch (error) {
        console.error('搜索失败:', error.message);
        res.status(500).json({ code: 500, message: '搜索服务暂时不可用' });
    }
});

// GET /api/music/url?id=xxx — 获取歌曲播放地址
router.get('/url', async (req, res) => {
    try {
        const { id } = req.query;
        if (!id) {
            return res.status(400).json({ code: 400, message: '歌曲ID不能为空' });
        }

        const result = await song_url_v1({
            id: parseInt(id),
            level: 'exhigh'
        });

        const urlData = result.body.data[0];
        if (urlData && urlData.url) {
            res.json({
                code: 200,
                message: '获取成功',
                data: { url: urlData.url, type: urlData.type, size: urlData.size }
            });
        } else {
            res.json({ code: 404, message: '该歌曲暂无可用音源（可能是VIP专属）', data: null });
        }
    } catch (error) {
        console.error('获取播放地址失败:', error.message);
        res.status(500).json({ code: 500, message: '获取播放地址失败' });
    }
});

// GET /api/music/hot — 获取推荐新歌
router.get('/hot', async (req, res) => {
    try {
        const result = await personalized_newsong({ limit: 20 });

        const songs = (result.body.result || []).map(item => {
            const song = item.song;
            return {
                id: song.id,
                title: song.name,
                artist: song.artists.map(a => a.name).join(' / '),
                album: song.album ? song.album.name : '',
                cover_url: song.album ? song.album.picUrl : '',
                duration: song.duration || 0
            };
        });

        res.json({ code: 200, message: '获取推荐成功', data: songs });
    } catch (error) {
        console.error('获取推荐失败:', error.message);
        res.status(500).json({ code: 500, message: '推荐服务暂时不可用' });
    }
});

// GET /api/music/detail?id=xxx — 获取歌曲详情
router.get('/detail', async (req, res) => {
    try {
        const { id } = req.query;
        if (!id) {
            return res.status(400).json({ code: 400, message: '歌曲ID不能为空' });
        }

        const result = await song_detail({ ids: id.toString() });
        const song = result.body.songs[0];

        if (song) {
            res.json({
                code: 200,
                message: '获取成功',
                data: {
                    id: song.id,
                    title: song.name,
                    artist: song.ar.map(a => a.name).join(' / '),
                    album: song.al ? song.al.name : '',
                    cover_url: song.al ? song.al.picUrl : '',
                    duration: song.dt || 0
                }
            });
        } else {
            res.json({ code: 404, message: '歌曲不存在', data: null });
        }
    } catch (error) {
        console.error('获取详情失败:', error.message);
        res.status(500).json({ code: 500, message: '获取歌曲详情失败' });
    }
});

module.exports = router;
