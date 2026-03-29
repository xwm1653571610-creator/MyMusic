import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { PreferenceUtil } from '../utils/PreferenceUtil';
import { HttpUtil } from '../utils/HttpUtil';
import { PlayerManager, Song } from '../managers/PlayerManager';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import request from '@ohos.request';
import common from '@ohos.app.ability.common';

export interface FavoriteResponseData { isFavorite: boolean; }
export interface FavoriteRequestData { user_id: number; song_id: number; }
export class UploadHeader { 'content-type': string = 'multipart/form-data'; }

@Entry
@Component
struct Main {
    @StorageLink('currentSong') currentSong: Song | null = null;
    @StorageLink('isPlaying') isPlaying: boolean = false;
    @StorageLink('currentTime') currentTime: number = 0;
    @StorageLink('totalTime') totalTime: number = 0;
    @StorageLink('userId') userId: number = 0;

    @State songs: Song[] = [];
    @State favoriteSongs: Song[] = [];
    @State searchKeyword: string = '';
    @State isPlayerFullScreen: boolean = false;
    // 用于驱动专辑封面的旋转属性
    @State coverAngle: number = 0;

    // 定时器引用，保证转圈动效
    private rotateIntervalId: number = -1;

    async aboutToAppear() {
        PlayerManager.getInstance(); // 初始化全局播放器单例

        this.fetchSongs();
        this.fetchFavorites();
        
        // 绑定一个帧渲染定时器处理旋转 (33ms 大约 30FPS)
        this.rotateIntervalId = setInterval(() => {
            if (this.isPlaying) {
                this.coverAngle = (this.coverAngle + 1) % 360;
            }
        }, 33) as unknown as number;
    }
    
    aboutToDisappear() {
        if (this.rotateIntervalId !== -1) {
            clearInterval(this.rotateIntervalId);
        }
    }

    async fetchSongs() {
        let res = await HttpUtil.get<Song[]>('/songs');
        if (res && res.code === 200 && res.data) {
            this.songs = res.data;
        }
    }

    async fetchFavorites() {
        if (!this.userId) return;
        let res = await HttpUtil.get<Song[]>(`/favorites/${this.userId}`);
        if (res && res.code === 200 && res.data) {
            this.favoriteSongs = res.data;
        }
    }

    async handleSearch() {
        if (!this.searchKeyword) {
            this.fetchSongs(); 
            return;
        }
        let res = await HttpUtil.get<Song[]>(`/songs/search?keyword=${encodeURIComponent(this.searchKeyword)}`);
        if (res && res.code === 200 && res.data) {
            this.songs = res.data;
            if (this.songs.length === 0) {
                promptAction.showToast({ message: '未搜到相关歌曲' });
            }
        }
    }

    async toggleFavorite(song: Song) {
        if (!this.userId) return;
        let reqData: FavoriteRequestData = { user_id: this.userId, song_id: song.id };
        let res = await HttpUtil.post<FavoriteResponseData>('/favorites', reqData);
        if (res && res.code === 200 && res.data) {
            if (res.data.isFavorite) {
                this.favoriteSongs.push(song);
                promptAction.showToast({message: '已收藏至我的歌单'});
            } else {
                this.favoriteSongs = this.favoriteSongs.filter(s => s.id !== song.id);
                promptAction.showToast({message: '已取消收藏'});
            }
        }
    }

    async handleUpload() {
        let audioPicker = new picker.AudioViewPicker();
        let audioSelectOpt = new picker.AudioSelectOptions();
        
        try {
            let pickResult = await audioPicker.select(audioSelectOpt);
            if (pickResult && pickResult.length > 0) {
                let uri = pickResult[0];
                let context = getContext(this) as common.UIAbilityContext;
                
                let fileName = 'upload_harmony_' + Date.now() + '.mp3';
                let destPath = context.cacheDir + '/' + fileName;
                
                let file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
                fs.copyFileSync(file.fd, destPath);
                fs.closeSync(file);

                promptAction.showToast({ message: '正在上传本机音频...' });

                let reqHeader: UploadHeader = new UploadHeader();
                let reqFile: request.File = { filename: fileName, name: 'audio', uri: 'internal://cache/' + fileName, type: 'audio/mpeg' };
                let reqFiles: Array<request.File> = [reqFile];
                
                let data1: request.RequestData = { name: 'title', value: '鸿蒙本机直传音乐' };
                let data2: request.RequestData = { name: 'artist', value: 'MyMusic 创作者' };
                let reqDataArr: Array<request.RequestData> = [data1, data2];

                let uploadConfig: request.UploadConfig = {
                    url: 'http://10.159.118.60:3000/api/songs/upload',
                    header: reqHeader as unknown as Record<string, string>, // 强制兼容
                    method: 'POST',
                    files: reqFiles,
                    data: reqDataArr
                };

                let uploadTask = await request.uploadFile(context, uploadConfig);
                uploadTask.on('complete', () => {
                    promptAction.showToast({ message: '发布成功！' });
                    this.fetchSongs();
                });
                uploadTask.on('fail', () => {
                    promptAction.showToast({ message: '上传失败' });
                });
            }
        } catch (error) {
            console.error('上传挂起报错', JSON.stringify(error));
        }
    }

    async handleLogout() {
        await PreferenceUtil.delete(getContext(this), 'token');
        await PreferenceUtil.delete(getContext(this), 'userId');
        HttpUtil.setToken('');
        AppStorage.setOrCreate<number>('userId', 0);
        PlayerManager.getInstance().stop();
        router.replaceUrl({ url: 'pages/Login' });
    }

    formatTime(ms: number): string {
        if (!ms) return '00:00';
        let totalSeconds = Math.floor(ms / 1000);
        let minutes = Math.floor(totalSeconds / 60);
        let seconds = totalSeconds % 60;
        return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    }

    // ==========================================================
    //                        UI 视图组件定义
    // ==========================================================

    @Builder SongItemView(song: Song) {
        Row({ space: 15 }) {
            // 左侧缩略图
            if (song.cover_url && song.cover_url.startsWith('http')) {
                Image(song.cover_url).width(50).height(50).borderRadius(8)
            } else {
                Circle({ width: 50, height: 50 }).fill('#333333')
            }

            // 中间元数据
            Column() {
                Text(song.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#E0E0E0').maxLines(1)
                Text(song.artist).fontSize(12).fontColor('#888888').margin({ top: 5 })
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)

            // 右侧互动区
            Row({space: 15}) {
                Text(this.favoriteSongs.some(s => s.id === song.id) ? '❤️' : '🤍')
                    .fontSize(22)
                    .onClick(() => { this.toggleFavorite(song); })

                if (this.currentSong?.id === song.id && this.isPlaying) {
                    // 转圈圈的小碟子动画示意
                    LoadingProgress().width(24).height(24).color('#007DFF')
                } else {
                    Text('▶').fontSize(20).fontColor('#AAAAAA')
                }
            }
        }
        .width('100%').padding(15)
        .backgroundColor('rgba(255, 255, 255, 0.03)')
        .borderRadius(12)
    }

    @Builder DiscoverView() {
        Column() {
            // 大横幅 Swiper
            Swiper() {
                Stack() {
                    Image('https://cdn-icons-png.flaticon.com/512/3011/3011236.png')
                        .width('100%').height(160).objectFit(ImageFit.Cover).borderRadius(15).opacity(0.6)
                    Text('最新推荐单曲').fontSize(24).fontWeight(FontWeight.Bolder).fontColor(Color.White)
                }
                Stack() {
                    Rect().width('100%').height(160).fill('#212121').borderRadius(15)
                    Text('周杰伦 - 经典回忆').fontSize(24).fontWeight(FontWeight.Bolder).fontColor(Color.White)
                }
            }
            .width('95%').height(160).margin({ top: 10, bottom: 10 })
            .autoPlay(true).interval(3000)

            // 搜索框
            Row() {
                TextInput({ placeholder: '搜索百万曲库...', text: this.searchKeyword })
                    .layoutWeight(1).height(45)
                    .backgroundColor('rgba(255, 255, 255, 0.1)')
                    .fontColor(Color.White)
                    .onChange((value) => { this.searchKeyword = value })
                    .onSubmit(() => { this.handleSearch() })

                Button('搜索').height(45).margin({ left: 10 }).backgroundColor('#007DFF').onClick(() => { this.handleSearch() })
            }.width('95%').margin({ bottom: 15 })

            List({ space: 10 }) {
                ForEach(this.songs, (song: Song) => {
                    ListItem() {
                        this.SongItemView(song)
                    }
                    .onClick(() => {
                        PlayerManager.getInstance().playSong(song);
                        this.isPlayerFullScreen = true;
                    })
                }, (song: Song) => song.id.toString())
            }
            .layoutWeight(1)
            .width('95%')
        }
        .width('100%').height('100%')
    }

    @Builder MineView() {
        Column({ space: 15 }) {
            Row() {
                Column() {
                    Text('我的空间').fontSize(28).fontWeight(FontWeight.Bolder).fontColor(Color.White)
                    Text('探索灵魂深处的声音').fontSize(14).fontColor(Color.Gray).margin({ top: 5 })
                }.alignItems(HorizontalAlign.Start)
                
                Blank()
                Button('退出').backgroundColor('red').onClick(() => this.handleLogout())
            }.width('90%').padding({ top: 20 })

            Row() {
                Column({ space: 10 }) {
                    Text('📤').fontSize(32)
                    Text('本地发布').fontColor(Color.White)
                }
                .backgroundColor('rgba(0,125,255, 0.2)').width('45%').height(100)
                .justifyContent(FlexAlign.Center).borderRadius(15)
                .onClick(() => this.handleUpload())

                Column({ space: 10 }) {
                    Text('🎧').fontSize(32)
                    Text('最近播放').fontColor(Color.White)
                }
                .backgroundColor('rgba(255,255,255, 0.1)').width('45%').height(100)
                .justifyContent(FlexAlign.Center).borderRadius(15)
            }.width('90%').justifyContent(FlexAlign.SpaceBetween)

            Text('我的红心收藏').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).width('90%').margin({ top: 10 })

            List({ space: 10 }) {
                ForEach(this.favoriteSongs, (song: Song) => {
                    ListItem() {
                        this.SongItemView(song)
                    }
                    .onClick(() => {
                        PlayerManager.getInstance().playSong(song);
                        this.isPlayerFullScreen = true;
                    })
                }, (song: Song) => song.id.toString())
            }
            .layoutWeight(1).width('95%')
        }
        .width('100%').height('100%')
    }

    @Builder MiniPlayerBar() {
        if (this.currentSong) {
            Row() {
                // 旋转小唱片 (缩略)
                if (this.currentSong.cover_url && this.currentSong.cover_url.startsWith('http')) {
                    Image(this.currentSong.cover_url)
                        .width(44).height(44).borderRadius(22)
                        .margin({ left: 15, right: 15 })
                        .rotate({ z: 1, angle: this.coverAngle })
                } else {
                    Circle({ width: 44, height: 44 }).fill('#222222').margin({ left: 15, right: 15 })
                }

                Column() {
                    Text(this.currentSong.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White).maxLines(1)
                    Text(this.currentSong.artist).fontSize(12).fontColor('#AAAAAA').margin({ top: 2 }).maxLines(1)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                Button(this.isPlaying ? '⏸' : '▶')
                    .fontSize(18).backgroundColor(Color.Transparent).fontColor(Color.White)
                    .onClick((e) => {
                        e.stopPropagation();
                        PlayerManager.getInstance().togglePlay();
                    })
            }
            .width('95%').height(65)
            .margin({ bottom: 15 }) // 让它稍微悬浮在底部
            .backgroundColor('rgba(0,0,0,0.85)')
            .borderRadius(35)
            .shadow({ radius: 20, color: 'rgba(0,0,0,0.5)', offsetY: 5 })
            .onClick(() => {
                this.isPlayerFullScreen = true;
            })
            .bindContentCover($$this.isPlayerFullScreen, this.FullScreenPlayerView())
        }
    }

    @Builder FullScreenPlayerView() {
        Column() {
            // 下拉返回头
            Row() {
                Text('🔽 返回桌面').fontSize(16).fontColor('#CCCCCC').padding(20)
            }.width('100%').justifyContent(FlexAlign.Start).onClick(() => { this.isPlayerFullScreen = false })

            Column({space: 40}) {
                // 大大的旋转黑胶唱片！
                Stack({ alignContent: Alignment.Center }) {
                    // 底盘模拟黑胶
                    Circle({ width: 300, height: 300 }).fill('#111111').shadow({radius: 40, color: '#000000'})
                    if (this.currentSong?.cover_url && this.currentSong.cover_url.startsWith('http')) {
                        Image(this.currentSong.cover_url)
                            .width(200).height(200).borderRadius(100)
                            .rotate({ z: 1, angle: this.coverAngle }) // 核心微动效！
                    } else {
                        Circle({ width: 200, height: 200 }).fill('#333333')
                    }
                }.margin({top: 40})

                // 核心歌曲信息
                Column({space: 10}) {
                    Text(this.currentSong?.title).fontSize(34).fontWeight(FontWeight.Bolder).fontColor(Color.White)
                    Text(this.currentSong?.artist).fontSize(18).fontColor('#888888')
                }

                // 进度条控制
                Row({space: 15}) {
                    Text(this.formatTime(this.currentTime)).fontColor('#CCCCCC').fontSize(13)
                    Slider({ 
                        value: this.currentTime, 
                        min: 0, 
                        max: this.totalTime > 0 ? this.totalTime : 100,
                        style: SliderStyle.OutSet
                    })
                    .layoutWeight(1)
                    .trackColor('rgba(255,255,255,0.2)')
                    .selectedColor('#007DFF')
                    .onChange((value: number, mode: SliderChangeMode) => {
                        if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                            PlayerManager.getInstance().seek(value);
                        }
                    })
                    Text(this.formatTime(this.totalTime)).fontColor('#CCCCCC').fontSize(13)
                }.width('90%')

                // 底部大控制器 (拟态质感)
                Row({space: 40}) {
                    Text('⏮').fontSize(36).fontColor(Color.White)
                    Text(this.isPlaying ? '⏸' : '▶').fontSize(70).fontColor('#007DFF').onClick(() => { PlayerManager.getInstance().togglePlay() })
                    Text('⏭').fontSize(36).fontColor(Color.White)
                }.margin({top: 20}).alignItems(VerticalAlign.Center)
            }
            .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        }
        .width('100%').height('100%')
        // 动态毛玻璃背景！
        .backgroundColor('#1A1C20')
    }

    build() {
        Stack({ alignContent: Alignment.Bottom }) {
            // 背景底图层 (暗色星空)
            Rect().width('100%').height('100%').fill('#0A0A0A')

            Tabs({ barPosition: BarPosition.End }) {
                TabContent() {
                    this.DiscoverView()
                }
                .tabBar('发 现')
                .backgroundColor(Color.Transparent)

                TabContent() {
                    this.MineView()
                }
                .tabBar('我 的')
                .backgroundColor(Color.Transparent)
            }
            .barBackgroundColor('#111111')
            .scrollable(true)
            .width('100%').height('100%')

            // 悬浮在所有的最上方，永驻的超前卫 Capsule 迷你播放条
            Column() {
                this.MiniPlayerBar()
            }.width('100%').padding({ bottom: 50 }) // 为底部系统 Tabs 留出位置
        }
        .width('100%').height('100%')
    }
}
