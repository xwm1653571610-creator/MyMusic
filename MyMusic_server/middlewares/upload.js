const multer = require('multer');
const path = require('path');

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
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({ storage: storage });

module.exports = upload;
