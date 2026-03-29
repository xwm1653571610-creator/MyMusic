const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../db');

// POST /api/users/register - 用户注册
router.post('/register', async (req, res) => {
    try {
        const { username, password } = req.body;
        if (!username || !password) {
            return res.status(400).json({ code: 400, message: '用户名和密码不能为空' });
        }

        const [existing] = await db.query('SELECT id FROM users WHERE username = ?', [username]);
        if (existing.length > 0) {
            return res.status(409).json({ code: 409, message: '用户名已被注册' });
        }

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

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
router.post('/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        const [users] = await db.query('SELECT * FROM users WHERE username = ?', [username]);
        if (users.length === 0) {
            return res.status(401).json({ code: 401, message: '用户名或密码错误' });
        }

        const user = users[0];
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(401).json({ code: 401, message: '用户名或密码错误' });
        }

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

module.exports = router;
