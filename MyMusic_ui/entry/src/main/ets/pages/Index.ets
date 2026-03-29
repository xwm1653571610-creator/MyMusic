import { HttpUtil } from '../utils/HttpUtil';
import promptAction from '@ohos.promptAction';
import { PreferenceUtil } from '../utils/PreferenceUtil';
import media from '@ohos.multimedia.media';

// 定义歌曲接口
export interface Song {
    id: number;
    title: string;
    artist: string;
    cover_url: string;
    audio_url: string;
}

// 可选：定义登录返回的数据格式
export interface LoginResponseData {
    token: string;
}

export interface RegisterResponseData {
    userId: number;
}

@Entry
@Component
struct Index {
    // 状态管理
    @State isLoggedIn: boolean = false;
    @State isRegisterMode: boolean = false;
    @State usernameInput: string = 'testuser'; // 为了测试方便给个默认值
    @State passwordInput: string = '123456';

    @State songs: Song[] = [];
    @State searchKeyword: string = '';

    // ======= 播放器相关状态 =======
    @State currentSong: Song | null = null;
    @State isPlaying: boolean = false;
    private avPlayer: media.AVPlayer | null = null;
    // ==============================

    async aboutToAppear() {
        this.initAVPlayer();
        // 读取本地存储，判断是否已经登录过
        let token = await PreferenceUtil.get(getContext(this), 'token', '') as string;
        if (token) {
            this.isLoggedIn = true;
            this.fetchSongs();
        }
    }

    // ---------------- UI: 登录模块 ----------------
    @Builder LoginView() {
        Column({ space: 20 }) {
            Text(this.isRegisterMode ? '欢迎注册' : '音乐世界')
                .fontSize(36).fontWeight(FontWeight.Bold).margin({ top: 100, bottom: 50 })

            TextInput({ placeholder: '请输入用户名', text: this.usernameInput })
                .onChange((value) => { this.usernameInput = value })
                .width('80%').height(50)

            TextInput({ placeholder: '请输入密码', text: this.passwordInput })
                .type(InputType.Password)
                .onChange((value) => { this.passwordInput = value })
                .width('80%').height(50)

            Button(this.isRegisterMode ? '注 册' : '登 录')
                .width('80%').height(50).margin({ top: 20 })
                .onClick(() => {
                    if (this.isRegisterMode) {
                        this.handleRegister();
                    } else {
                        this.handleLogin();
                    }
                })

            Text(this.isRegisterMode ? '已有账号？去登录' : '没有账号？去注册')
                .fontColor(Color.Blue)
                .fontSize(14)
                .padding(10)
                .onClick(() => {
                    this.isRegisterMode = !this.isRegisterMode;
                })
        }
        .width('100%').height('100%')
        .alignItems(HorizontalAlign.Center)
    }

    // ---------------- UI: 歌曲列表模块 ----------------
    @Builder MusicListView() {
        Column() {
            // 搜索栏
            Row({ space: 10 }) {
                TextInput({ placeholder: '搜索歌曲或歌手...', text: this.searchKeyword })
                    .layoutWeight(1).height(40)
                    .onChange((value) => { this.searchKeyword = value })
                    .onSubmit(() => { this.handleSearch() }) // 键盘回车搜索

                Button('搜索').height(40)
                    .onClick(() => { this.handleSearch() })

                Button('退出').height(40).backgroundColor(Color.Red)
                    .onClick(() => { this.handleLogout() })
            }.width('100%').padding(15)

            // 歌曲列表
            List({ space: 15 }) {
                ForEach(this.songs, (song: Song) => {
                    ListItem() {
                        Row({ space: 15 }) {
                            // 尝试使用真实的封面图，如果没有则走占位
                            if (song.cover_url && song.cover_url.startsWith('http')) {
                                Image(song.cover_url).width(50).height(50).borderRadius(25)
                            } else {
                                Circle({ width: 50, height: 50 }).fill('#E0E0E0')
                            }

                            Column() {
                                Text(song.title).fontSize(18).fontWeight(FontWeight.Bold)
                                Text(song.artist).fontSize(14).fontColor(Color.Gray).margin({ top: 5 })
                            }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                            // 渲染当前播放状态
                            if (this.currentSong?.id === song.id && this.isPlaying) {
                                Text('⏸').fontSize(24).fontColor('#007DFF')
                            } else {
                                Text('▶').fontSize(24).fontColor('#007DFF')
                            }
                        }
                        .width('100%').padding({ left: 15, right: 15 })
                        .onClick(() => {
                            // 点击某首歌曲直接播放
                            if (this.currentSong?.id === song.id) {
                                this.togglePlay();
                            } else {
                                this.playSong(song);
                            }
                        })
                    }
                }, (song: Song) => song.id.toString())
            }
            .layoutWeight(1)
            .width('100%')
        }
        .width('100%').height('100%')
    }

    // ---------------- 核心逻辑 ----------------

    async handleRegister() {
        if (!this.usernameInput || !this.passwordInput) {
            promptAction.showToast({ message: '请输入账号密码' });
            return;
        }

        let requestData: Record<string, string> = {
            'username': this.usernameInput,
            'password': this.passwordInput
        };

        // 发起注册请求
        let res = await HttpUtil.post<RegisterResponseData>('/users/register', requestData);

        if (res && res.code === 200) {
            promptAction.showToast({ message: '注册成功，请登录' });
            // 注册成功后自动切换回登录模式
            this.isRegisterMode = false;
        } else {
            promptAction.showToast({ message: res?.message || '注册失败' });
        }
    }

    async handleLogin() {
        if (!this.usernameInput || !this.passwordInput) {
            promptAction.showToast({ message: '请输入账号密码' });
            return;
        }

        // 修复 arkts-no-untyped-obj-literals 报错：使用 Record 明确对象类型
        let requestData: Record<string, string> = {
            'username': this.usernameInput,
            'password': this.passwordInput
        };

        // 发起请求并指明返回 data 的类型
        let res = await HttpUtil.post<LoginResponseData>('/users/login', requestData);

        if (res && res.code === 200 && res.data) {
            promptAction.showToast({ message: '登录成功' });
            
            // 将 token 持久化到本地存储
            await PreferenceUtil.put(getContext(this), 'token', res.data.token);

            this.isLoggedIn = true;
            // 登录成功后立刻拉取全部歌曲
            this.fetchSongs();
        } else {
            promptAction.showToast({ message: res?.message || '登录失败，请检查账号密码' });
        }
    }

    async fetchSongs() {
        // 明确告诉 HttpUtil，返回的 data 是 Song 数组 (Song[])
        let res = await HttpUtil.get<Song[]>('/songs');
        if (res && res.code === 200 && res.data) {
            this.songs = res.data;
        }
    }

    async handleSearch() {
        if (!this.searchKeyword) {
            this.fetchSongs(); // 关键字为空则获取全部
            return;
        }
        // 明确返回的是 Song[]
        let res = await HttpUtil.get<Song[]>(`/songs/search?keyword=${encodeURIComponent(this.searchKeyword)}`);
        if (res && res.code === 200 && res.data) {
            this.songs = res.data;
            if (this.songs.length === 0) {
                promptAction.showToast({ message: '未搜到相关歌曲' });
            }
        }
    }

    async handleLogout() {
        // 清除本地存储的 token
        await PreferenceUtil.delete(getContext(this), 'token');
        this.isLoggedIn = false;
        this.songs = [];
        this.searchKeyword = '';
        this.currentSong = null;
        if (this.avPlayer) {
             this.avPlayer.stop();
             this.isPlaying = false;
        }
        promptAction.showToast({ message: '已退出登录' });
    }

    // ---------------- 播放器核心逻辑 ----------------
    
    async initAVPlayer() {
        try {
            this.avPlayer = await media.createAVPlayer();
            this.setAVPlayerCallback();
        } catch (error) {
            console.error('AVPlayer init error', JSON.stringify(error));
        }
    }

    setAVPlayerCallback() {
        if (!this.avPlayer) return;
        this.avPlayer.on('stateChange', async (state: string, reason: media.StateChangeReason) => {
            switch (state) {
                case 'initialized':
                    this.avPlayer?.prepare();
                    break;
                case 'prepared':
                    this.avPlayer?.play();
                    this.isPlaying = true;
                    break;
                case 'playing':
                    this.isPlaying = true;
                    break;
                case 'paused':
                case 'completed':
                case 'stopped':
                case 'error':
                    this.isPlaying = false;
                    break;
            }
        });
    }

    playSong(song: Song) {
        this.currentSong = song;
        if (!this.avPlayer) return;

        this.avPlayer.reset().then(() => {
            if (song.audio_url && this.avPlayer) {
                // 设置 url 会自动触发 initialized 状态并被监听到，从而开始准备和播放
                this.avPlayer.url = song.audio_url; 
            } else {
                promptAction.showToast({ message: '此歌曲暂无音频资源' });
            }
        });
    }

    togglePlay() {
        if (!this.avPlayer) return;
        if (this.isPlaying) {
            this.avPlayer.pause();
        } else {
            this.avPlayer.play();
        }
    }

    @Builder PlayerBarView() {
        if (this.currentSong) {
            Row() {
                // 封面
                if (this.currentSong.cover_url && this.currentSong.cover_url.startsWith('http')) {
                    Image(this.currentSong.cover_url).width(40).height(40).borderRadius(20)
                } else {
                    Circle({ width: 40, height: 40 }).fill('#E0E0E0')
                }

                // 歌名
                Column() {
                    Text(this.currentSong.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
                    Text(this.currentSong.artist).fontSize(12).fontColor(Color.Gray).margin({ top: 2 })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 15 })

                // 播放控制按钮
                Button(this.isPlaying ? '暂停 ⏸' : '播放 ▶')
                    .fontSize(14)
                    .backgroundColor('#007DFF')
                    .height(30)
                    .onClick(() => {
                        this.togglePlay();
                    })
            }
            .width('100%').height(70).padding({ left: 20, right: 20 })
            .backgroundColor('#333333')
        }
    }

    // ---------------- 主构建函数 ----------------
    build() {
        Stack({ alignContent: Alignment.Bottom }) {
            if (this.isLoggedIn) {
                Column() {
                    Column() {
                        this.MusicListView()
                    }.layoutWeight(1)

                    this.PlayerBarView()
                }
                .width('100%').height('100%')
            } else {
                this.LoginView()
            }
        }
        .width('100%').height('100%')
    }
}