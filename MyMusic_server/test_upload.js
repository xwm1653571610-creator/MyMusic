const fs = require('fs');
const path = require('path');

// 由于不想再引入 axios / form-data 依赖增加你的负担，这里使用 Node 18+ 内置的 fetch 和 FormData 测试
async function testUpload() {
    try {
        console.log('准备测试上传...');
        
        // 确保你的 public 目录里有一个我们刚刚下载的 test_song.mp3
        const audioPath = path.join(__dirname, 'public', 'test_song.mp3');
        if (!fs.existsSync(audioPath)) {
            console.error('找不到测试文件 public/test_song.mp3，请确认文件存在！');
            return;
        }

        // 把本地文件转化为 blob 模拟网页端 File 对象
        const audioBuffer = fs.readFileSync(audioPath);
        const audioBlob = new Blob([audioBuffer], { type: 'audio/mpeg' });

        const formData = new FormData();
        formData.append('title', 'API测试神曲');
        formData.append('artist', 'Node 机器人');
        formData.append('album', '全自动专辑');
        // field 名字一定要和 app.js multer 里配置的 'audio' 一致
        formData.append('audio', audioBlob, 'test_song.mp3');

        console.log('正在向服务端 POST /api/songs/upload 请求...');
        const response = await fetch('http://localhost:3000/api/songs/upload', {
            method: 'POST',
            body: formData
        });

        const result = await response.json();
        console.log('服务器返回结果:', JSON.stringify(result, null, 2));

    } catch (err) {
        console.error('测试报错:', err);
    }
}

testUpload();
