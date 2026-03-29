const pool = require('./db');

async function run() {
    try {
        // 更新 id=1 的歌曲为真实的测试音频 URL
        const realAudioUrl = 'http://10.159.118.60:3000/static/test_song.mp3';
        const realCoverUrl = 'https://picsum.photos/200'; // 借用一个漂亮的封面占位图

        await pool.query(
            "UPDATE songs SET audio_url = ?, cover_url = ? WHERE id = 1",
            [realAudioUrl, realCoverUrl]
        );
        console.log("SUCCESS: 数据库 ID=1 ('夜曲') 音频数据更新完成！");

        await pool.query(
            "UPDATE songs SET audio_url = ?, cover_url = ? WHERE id = 2",
            [realAudioUrl, realCoverUrl]
        );
        console.log("SUCCESS: 数据库 ID=2 ('富士山下') 音频数据更新完成！");

        process.exit(0);
    } catch (err) {
        console.error("更新失败：", err);
        process.exit(1);
    }
}
run();
