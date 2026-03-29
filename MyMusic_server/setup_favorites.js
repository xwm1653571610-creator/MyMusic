const pool = require('./db');

async function run() {
    console.log("正在连接数据库创建 favorites 表...");
    try {
        const createTableSql = `
            CREATE TABLE IF NOT EXISTS favorites (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                song_id INT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY user_song_unique (user_id, song_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        `;
        
        await pool.query(createTableSql);
        console.log("✅ 成功拉起 favorites 收藏关系表！");
        process.exit(0);
    } catch (err) {
        console.error("❌ 建立表失败:", err);
        process.exit(1);
    }
}
run();
