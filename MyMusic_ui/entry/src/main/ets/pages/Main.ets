import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { PreferenceUtil } from '../utils/PreferenceUtil';
import { HttpUtil } from '../utils/HttpUtil';
import { PlayerManager, Song } from '../managers/PlayerManager';

// 收藏相关接口声明
export interface FavoriteResponseData {
    isFavorite: boolean;
}

export interface FavoriteRequestBody {
    user_id: number;
    song_id: number;
    title: string;
    artist: string;
    cover_url: string;
}

// 网易云音频URL返回
export interface AudioUrlData {
    url: string;
    type: string;
    size: number;
}

@Entry
@Component
struct Main {
    @StorageLink('currentSong') currentSong: Song | null = null;
    @StorageLink('isPlaying') isPlaying: boolean = false;
    @StorageLink('currentTime') currentTime: number = 0;
    @StorageLink('totalTime') totalTime: number = 0;
    @StorageLink('userId') userId: number = 0;

    @State hotSongs: Song[] = [];
    @State searchResults: Song[] = [];
    @State favoriteSongs: Song[] = [];
    @State searchKeyword: string = '';
    @State isSearching: boolean = false;
    @State isPlayerFullScreen: boolean = false;
    @State coverAngle: number = 0;
    @State currentTab: number = 0;

    private rotateTimerId: number = -1;

    aboutToAppear(): void {
        PlayerManager.getInstance();
        this.loadHotSongs();
        this.loadFavorites();

        let timerId: number = setInterval((): void => {
            if (this.isPlaying) {
                this.coverAngle = (this.coverAngle + 1) % 360;
            }
        }, 33);
        this.rotateTimerId = timerId;
    }

    aboutToDisappear(): void {
        if (this.rotateTimerId !== -1) {
            clearInterval(this.rotateTimerId);
        }
    }

    // ========== 网络请求 ==========

    async loadHotSongs(): Promise<void> {
        let res = await HttpUtil.get<Song[]>('/music/hot');
        if (res && res.code === 200 && res.data) {
            this.hotSongs = res.data;
        }
    }

    async loadFavorites(): Promise<void> {
        if (!this.userId) return;
        let res = await HttpUtil.get<Song[]>(`/favorites/${this.userId}`);
        if (res && res.code === 200 && res.data) {
            this.favoriteSongs = res.data;
        }
    }

    async doSearch(): Promise<void> {
        if (!this.searchKeyword) {
            this.searchResults = [];
            this.isSearching = false;
            return;
        }
        this.isSearching = true;
        let res = await HttpUtil.get<Song[]>(`/music/search?keyword=${encodeURIComponent(this.searchKeyword)}`);
        if (res && res.code === 200 && res.data) {
            this.searchResults = res.data;
            if (this.searchResults.length === 0) {
                promptAction.showToast({ message: '未找到相关歌曲' });
            }
        }
    }

    async playSong(song: Song, list: Song[], index: number): Promise<void> {
        // 先从后端获取真实播放地址
        let res = await HttpUtil.get<AudioUrlData>(`/music/url?id=${song.id}`);
        if (res && res.code === 200 && res.data && res.data.url) {
            PlayerManager.getInstance().setSongList(list, index);
            PlayerManager.getInstance().playSongByUrl(song, res.data.url);
        } else {
            promptAction.showToast({ message: '该歌曲暂无可用音源' });
        }
    }

    async toggleFavorite(song: Song): Promise<void> {
        if (!this.userId) return;
        let reqData: FavoriteRequestBody = {
            user_id: this.userId,
            song_id: song.id,
            title: song.title,
            artist: song.artist,
            cover_url: song.cover_url
        };
        let res = await HttpUtil.post<FavoriteResponseData>('/favorites', reqData);
        if (res && res.code === 200 && res.data) {
            if (res.data.isFavorite) {
                this.favoriteSongs.push(song);
                promptAction.showToast({ message: '已收藏' });
            } else {
                this.favoriteSongs = this.favoriteSongs.filter((s: Song): boolean => s.id !== song.id);
                promptAction.showToast({ message: '已取消收藏' });
            }
        }
    }

    isFavorite(songId: number): boolean {
        return this.favoriteSongs.some((s: Song): boolean => s.id === songId);
    }

    async handleLogout(): Promise<void> {
        await PreferenceUtil.delete(getContext(this), 'token');
        await PreferenceUtil.delete(getContext(this), 'userId');
        HttpUtil.setToken('');
        AppStorage.setOrCreate<number>('userId', 0);
        PlayerManager.getInstance().stop();
        router.replaceUrl({ url: 'pages/Login' });
    }

    formatTime(ms: number): string {
        if (!ms || ms <= 0) return '00:00';
        let totalSec = Math.floor(ms / 1000);
        let min = Math.floor(totalSec / 60);
        let sec = totalSec % 60;
        let minStr = min < 10 ? '0' + min.toString() : min.toString();
        let secStr = sec < 10 ? '0' + sec.toString() : sec.toString();
        return minStr + ':' + secStr;
    }

    // ========== UI 组件 ==========

    @Builder SongRow(song: Song, list: Song[], idx: number) {
        Row({ space: 12 }) {
            // 序号
            Text((idx + 1).toString())
                .fontSize(14)
                .fontColor('#555555')
                .width(28)
                .textAlign(TextAlign.Center)

            // 封面
            if (song.cover_url) {
                Image(song.cover_url)
                    .width(48)
                    .height(48)
                    .borderRadius(6)
            } else {
                Column()
                    .width(48)
                    .height(48)
                    .borderRadius(6)
                    .backgroundColor('#222222')
            }

            // 歌名歌手
            Column({ space: 4 }) {
                Text(song.title)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.currentSong?.id === song.id ? '#007DFF' : '#E0E0E0')
                    .maxLines(1)

                Text(song.artist)
                    .fontSize(12)
                    .fontColor('#888888')
                    .maxLines(1)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            // 收藏
            Text(this.isFavorite(song.id) ? '❤️' : '🤍')
                .fontSize(20)
                .onClick((): void => {
                    this.toggleFavorite(song);
                })

            // 播放状态
            if (this.currentSong?.id === song.id && this.isPlaying) {
                LoadingProgress()
                    .width(20)
                    .height(20)
                    .color('#007DFF')
            } else {
                Text('▶')
                    .fontSize(16)
                    .fontColor('#666666')
            }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .onClick((): void => {
            this.playSong(song, list, idx);
        })
    }

    @Builder DiscoverPage() {
        Column() {
            // 搜索栏
            Row({ space: 10 }) {
                TextInput({ placeholder: '搜索歌曲、歌手...', text: this.searchKeyword })
                    .layoutWeight(1)
                    .height(42)
                    .backgroundColor('#1A1A2E')
                    .fontColor('#FFFFFF')
                    .placeholderColor('#666666')
                    .borderRadius(21)
                    .onChange((value: string): void => {
                        this.searchKeyword = value;
                        if (!value) {
                            this.isSearching = false;
                            this.searchResults = [];
                        }
                    })
                    .onSubmit((): void => {
                        this.doSearch();
                    })

                Button('搜索')
                    .height(42)
                    .backgroundColor('#007DFF')
                    .borderRadius(21)
                    .fontSize(14)
                    .onClick((): void => {
                        this.doSearch();
                    })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })

            if (this.isSearching && this.searchResults.length > 0) {
                // 搜索结果
                Column() {
                    Text(`搜索结果 (${this.searchResults.length})`)
                        .fontSize(18)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#FFFFFF')
                        .width('100%')
                        .padding({ left: 16, bottom: 10 })

                    List({ space: 2 }) {
                        ForEach(this.searchResults, (song: Song, index: number) => {
                            ListItem() {
                                this.SongRow(song, this.searchResults, index)
                            }
                        }, (song: Song): string => song.id.toString())
                    }
                    .layoutWeight(1)
                    .width('100%')
                }
                .layoutWeight(1)
            } else {
                // 推荐列表
                Column() {
                    Text('🔥 热门推荐')
                        .fontSize(20)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#FFFFFF')
                        .width('100%')
                        .padding({ left: 16, bottom: 10 })

                    List({ space: 2 }) {
                        ForEach(this.hotSongs, (song: Song, index: number) => {
                            ListItem() {
                                this.SongRow(song, this.hotSongs, index)
                            }
                        }, (song: Song): string => song.id.toString())
                    }
                    .layoutWeight(1)
                    .width('100%')
                }
                .layoutWeight(1)
            }
        }
        .width('100%')
        .height('100%')
    }

    @Builder MinePage() {
        Column() {
            // 用户信息头
            Row() {
                Column({ space: 5 }) {
                    Text('我的音乐')
                        .fontSize(26)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#FFFFFF')

                    Text('管理你的收藏与播放')
                        .fontSize(13)
                        .fontColor('#888888')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Button('退出')
                    .height(34)
                    .backgroundColor('#FF4444')
                    .fontSize(13)
                    .borderRadius(17)
                    .onClick((): void => {
                        this.handleLogout();
                    })
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 20, bottom: 15 })

            // 收藏标题
            Row() {
                Text('❤ 我的收藏')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')

                Blank()

                Text(this.favoriteSongs.length.toString() + ' 首')
                    .fontSize(13)
                    .fontColor('#888888')
            }
            .width('100%')
            .padding({ left: 20, right: 20, bottom: 10 })

            if (this.favoriteSongs.length === 0) {
                Column() {
                    Text('🎵')
                        .fontSize(60)
                        .margin({ bottom: 15 })

                    Text('还没有收藏歌曲')
                        .fontSize(16)
                        .fontColor('#666666')

                    Text('去发现页搜索喜欢的歌曲吧')
                        .fontSize(13)
                        .fontColor('#444444')
                        .margin({ top: 8 })
                }
                .layoutWeight(1)
                .justifyContent(FlexAlign.Center)
                .width('100%')
            } else {
                List({ space: 2 }) {
                    ForEach(this.favoriteSongs, (song: Song, index: number) => {
                        ListItem() {
                            this.SongRow(song, this.favoriteSongs, index)
                        }
                    }, (song: Song): string => song.id.toString())
                }
                .layoutWeight(1)
                .width('100%')
            }
        }
        .width('100%')
        .height('100%')
    }

    @Builder MiniPlayerBar() {
        if (this.currentSong) {
            Row({ space: 12 }) {
                // 旋转封面
                if (this.currentSong.cover_url) {
                    Image(this.currentSong.cover_url)
                        .width(42)
                        .height(42)
                        .borderRadius(21)
                        .rotate({ angle: this.coverAngle })
                } else {
                    Column()
                        .width(42)
                        .height(42)
                        .borderRadius(21)
                        .backgroundColor('#333333')
                }

                // 歌曲信息
                Column({ space: 3 }) {
                    Text(this.currentSong.title)
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#FFFFFF')
                        .maxLines(1)

                    Text(this.currentSong.artist)
                        .fontSize(11)
                        .fontColor('#AAAAAA')
                        .maxLines(1)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                // 播放按钮
                Text(this.isPlaying ? '⏸' : '▶')
                    .fontSize(22)
                    .fontColor('#FFFFFF')
                    .width(40)
                    .height(40)
                    .textAlign(TextAlign.Center)
                    .borderRadius(20)
                    .backgroundColor('rgba(255,255,255,0.1)')
                    .onClick((): void => {
                        PlayerManager.getInstance().togglePlay();
                    })
            }
            .width('92%')
            .height(62)
            .padding({ left: 10, right: 10 })
            .backgroundColor('rgba(20,20,30,0.95)')
            .borderRadius(31)
            .onClick((): void => {
                this.isPlayerFullScreen = true;
            })
            .bindContentCover($$this.isPlayerFullScreen, this.FullPlayerView())
        }
    }

    @Builder FullPlayerView() {
        Column() {
            // 顶部返回
            Row() {
                Text('⌄')
                    .fontSize(28)
                    .fontColor('#CCCCCC')
                    .padding(20)
                    .onClick((): void => {
                        this.isPlayerFullScreen = false;
                    })
            }
            .width('100%')

            // 旋转唱片区域
            Column({ space: 30 }) {
                Stack() {
                    // 外圈黑胶
                    Circle({ width: 280, height: 280 })
                        .fill('#111111')
                    // 封面
                    if (this.currentSong?.cover_url) {
                        Image(this.currentSong.cover_url)
                            .width(180)
                            .height(180)
                            .borderRadius(90)
                            .rotate({ angle: this.coverAngle })
                    } else {
                        Circle({ width: 180, height: 180 })
                            .fill('#333333')
                    }
                    // 中心圆点
                    Circle({ width: 20, height: 20 })
                        .fill('#0D0D0D')
                }
                .margin({ top: 30 })

                // 歌曲信息
                Column({ space: 8 }) {
                    Text(this.currentSong?.title || '')
                        .fontSize(26)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#FFFFFF')
                        .maxLines(1)

                    Text(this.currentSong?.artist || '')
                        .fontSize(16)
                        .fontColor('#888888')
                }

                // 进度条
                Column({ space: 8 }) {
                    Slider({
                        value: this.currentTime,
                        min: 0,
                        max: this.totalTime > 0 ? this.totalTime : 100,
                        style: SliderStyle.OutSet
                    })
                        .width('85%')
                        .trackColor('#333333')
                        .selectedColor('#007DFF')
                        .onChange((value: number, mode: SliderChangeMode): void => {
                            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                                PlayerManager.getInstance().seek(value);
                            }
                        })

                    Row() {
                        Text(this.formatTime(this.currentTime))
                            .fontSize(12)
                            .fontColor('#888888')

                        Blank()

                        Text(this.formatTime(this.totalTime))
                            .fontSize(12)
                            .fontColor('#888888')
                    }
                    .width('85%')
                }

                // 控制按钮
                Row({ space: 45 }) {
                    Text('⏮')
                        .fontSize(32)
                        .fontColor('#CCCCCC')
                        .onClick((): void => {
                            this.handlePrev();
                        })

                    Text(this.isPlaying ? '⏸' : '▶')
                        .fontSize(56)
                        .fontColor('#007DFF')
                        .onClick((): void => {
                            PlayerManager.getInstance().togglePlay();
                        })

                    Text('⏭')
                        .fontSize(32)
                        .fontColor('#CCCCCC')
                        .onClick((): void => {
                            this.handleNext();
                        })
                }
                .margin({ top: 10 })
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .width('100%')
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#0D0D0D')
    }

    async handleNext(): Promise<void> {
        let mgr = PlayerManager.getInstance();
        let list = mgr.getSongList();
        if (list.length === 0) return;
        let nextIdx = (mgr.getCurrentIndex() + 1) % list.length;
        let nextSong = list[nextIdx];
        await this.playSong(nextSong, list, nextIdx);
    }

    async handlePrev(): Promise<void> {
        let mgr = PlayerManager.getInstance();
        let list = mgr.getSongList();
        if (list.length === 0) return;
        let prevIdx = (mgr.getCurrentIndex() - 1 + list.length) % list.length;
        let prevSong = list[prevIdx];
        await this.playSong(prevSong, list, prevIdx);
    }

    // ========== 主构建 ==========

    build() {
        Stack({ alignContent: Alignment.Bottom }) {
            Column() {
                Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
                    TabContent() {
                        this.DiscoverPage()
                    }
                    .tabBar('发现')

                    TabContent() {
                        this.MinePage()
                    }
                    .tabBar('我的')
                }
                .barBackgroundColor('#111111')
                .barMode(BarMode.Fixed)
                .onChange((index: number): void => {
                    this.currentTab = index;
                    if (index === 1) {
                        this.loadFavorites();
                    }
                })
            }
            .width('100%')
            .height('100%')
            .backgroundColor('#0D0D0D')
            .padding({ bottom: this.currentSong ? 75 : 0 })

            // 悬浮播放条
            Column() {
                this.MiniPlayerBar()
            }
            .width('100%')
            .padding({ bottom: 55 })
        }
        .width('100%')
        .height('100%')
    }
}
