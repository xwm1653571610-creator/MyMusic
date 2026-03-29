const pool = require('./db');

async function rebuild() {
    try {
        console.log('🔨 开始重建数据库...');

        // 删除旧的 favorites 表
        await pool.query('DROP TABLE IF EXISTS favorites');
        console.log('✅ 旧 favorites 表已删除');

        // 创建新的 favorites 表（存储网易云歌曲信息）
        await pool.query(`
            CREATE TABLE favorites (
                id INT PRIMARY KEY AUTO_INCREMENT,
                user_id INT NOT NULL,
                song_id BIGINT NOT NULL,
                title VARCHAR(255) NOT NULL DEFAULT '',
                artist VARCHAR(255) NOT NULL DEFAULT '',
                cover_url VARCHAR(500) DEFAULT '',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY unique_fav (user_id, song_id),
                INDEX idx_user (user_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        `);
        console.log('✅ 新 favorites 表创建成功（网易云歌曲ID + 冗余元信息）');

        // 确保 users 表存在
        await pool.query(`
            CREATE TABLE IF NOT EXISTS users (
                id INT PRIMARY KEY AUTO_INCREMENT,
                username VARCHAR(50) NOT NULL UNIQUE,
                password VARCHAR(255) NOT NULL,
                avatar_url VARCHAR(500) DEFAULT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        `);
        console.log('✅ users 表确认就绪');

        console.log('\n🎉 数据库重建完毕！可以启动 node app.js 了');
        process.exit(0);
    } catch (err) {
        console.error('❌ 重建失败:', err);
        process.exit(1);
    }
}

rebuild();
