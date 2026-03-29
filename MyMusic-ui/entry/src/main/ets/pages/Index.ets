import { HttpUtil } from '../utils/HttpUtil';
import promptAction from '@ohos.promptAction';

// 定义歌曲接口
export interface Song {
    id: number;
    title: string;
    artist: string;
    cover_url: string;
}

// 可选：定义登录返回的数据格式
export interface LoginResponseData {
    token: string;
}

@Entry
@Component
struct Index {
    // 状态管理
    @State isLoggedIn: boolean = false;
    @State usernameInput: string = 'testuser'; // 为了测试方便给个默认值
    @State passwordInput: string = '123456';

    @State songs: Song[] = [];
    @State searchKeyword: string = '';

    // ---------------- UI: 登录模块 ----------------
    @Builder LoginView() {
        Column({ space: 20 }) {
            Text('音乐世界').fontSize(36).fontWeight(FontWeight.Bold).margin({ top: 100, bottom: 50 })

            TextInput({ placeholder: '请输入用户名', text: this.usernameInput })
                .onChange((value) => { this.usernameInput = value })
                .width('80%').height(50)

            TextInput({ placeholder: '请输入密码', text: this.passwordInput })
                .type(InputType.Password)
                .onChange((value) => { this.passwordInput = value })
                .width('80%').height(50)

            Button('登 录')
                .width('80%').height(50).margin({ top: 20 })
                .onClick(() => {
                    this.handleLogin();
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
            }.width('100%').padding(15)

            // 歌曲列表
            List({ space: 15 }) {
                ForEach(this.songs, (song: Song) => {
                    ListItem() {
                        Row({ space: 15 }) {
                            // 封面占位图 (实际开发可用 Image 组件加载 url)
                            Circle({ width: 50, height: 50 }).fill('#E0E0E0')

                            Column() {
                                Text(song.title).fontSize(18).fontWeight(FontWeight.Bold)
                                Text(song.artist).fontSize(14).fontColor(Color.Gray).margin({ top: 5 })
                            }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                            // 播放按钮占位
                            Text('▶').fontSize(24).fontColor('#007DFF')
                        }
                        .width('100%').padding({ left: 15, right: 15 })
                    }
                }, (song: Song) => song.id.toString())
            }
            .layoutWeight(1)
            .width('100%')
        }
        .width('100%').height('100%')
    }

    // ---------------- 核心逻辑 ----------------

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

        if (res && res.code === 200) {
            promptAction.showToast({ message: '登录成功' });
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

    // ---------------- 主构建函数 ----------------
    build() {
        Stack() {
            if (this.isLoggedIn) {
                this.MusicListView()
            } else {
                this.LoginView()
            }
        }
        .width('100%').height('100%')
    }
}