import media from '@ohos.multimedia.media';

// 歌曲数据接口（对应网易云返回的字段）
export interface Song {
    id: number;
    title: string;
    artist: string;
    cover_url: string;
    album: string;
    duration: number;
    audio_url: string;
}

// 模块级变量（ArkTS 禁止 static 方法中使用 this）
let playerInstance: PlayerManager | null = null;
let avPlayerInstance: media.AVPlayer | null = null;
let songListCache: Song[] = [];
let currentIndexCache: number = -1;

export class PlayerManager {

    private constructor() {
        AppStorage.setOrCreate<Song | null>('currentSong', null);
        AppStorage.setOrCreate<boolean>('isPlaying', false);
        AppStorage.setOrCreate<number>('currentTime', 0);
        AppStorage.setOrCreate<number>('totalTime', 0);
        this.initPlayer();
    }

    static getInstance(): PlayerManager {
        if (!playerInstance) {
            playerInstance = new PlayerManager();
        }
        return playerInstance;
    }

    private async initPlayer(): Promise<void> {
        try {
            avPlayerInstance = await media.createAVPlayer();
            this.bindCallbacks();
        } catch (e) {
            console.error('AVPlayer 初始化失败', JSON.stringify(e));
        }
    }

    private bindCallbacks(): void {
        if (!avPlayerInstance) return;

        avPlayerInstance.on('stateChange', (state: string): void => {
            switch (state) {
                case 'initialized':
                    avPlayerInstance?.prepare();
                    break;
                case 'prepared':
                    avPlayerInstance?.play();
                    AppStorage.set<boolean>('isPlaying', true);
                    let dur = avPlayerInstance?.duration;
                    if (dur) {
                        AppStorage.set<number>('totalTime', dur);
                    }
                    break;
                case 'playing':
                    AppStorage.set<boolean>('isPlaying', true);
                    break;
                case 'paused':
                    AppStorage.set<boolean>('isPlaying', false);
                    break;
                case 'completed':
                    AppStorage.set<boolean>('isPlaying', false);
                    // 自动播放下一首
                    PlayerManager.getInstance().playNext();
                    break;
                case 'stopped':
                case 'error':
                    AppStorage.set<boolean>('isPlaying', false);
                    break;
            }
        });

        avPlayerInstance.on('durationUpdate', (duration: number): void => {
            AppStorage.set<number>('totalTime', duration);
        });

        avPlayerInstance.on('timeUpdate', (time: number): void => {
            AppStorage.set<number>('currentTime', time);
        });
    }

    setSongList(list: Song[], startIndex: number): void {
        songListCache = list;
        currentIndexCache = startIndex;
    }

    playSongByUrl(song: Song, url: string): void {
        if (!avPlayerInstance) return;
        let songWithUrl: Song = {
            id: song.id,
            title: song.title,
            artist: song.artist,
            cover_url: song.cover_url,
            album: song.album,
            duration: song.duration,
            audio_url: url
        };
        AppStorage.set<Song | null>('currentSong', songWithUrl);
        AppStorage.set<number>('currentTime', 0);

        avPlayerInstance.reset().then((): void => {
            if (avPlayerInstance) {
                avPlayerInstance.url = url;
            }
        });
    }

    togglePlay(): void {
        if (!avPlayerInstance) return;
        let playing = AppStorage.get<boolean>('isPlaying');
        if (playing) {
            avPlayerInstance.pause();
        } else {
            avPlayerInstance.play();
        }
    }

    seek(timeMs: number): void {
        if (!avPlayerInstance) return;
        avPlayerInstance.seek(timeMs);
    }

    playNext(): void {
        if (songListCache.length === 0) return;
        currentIndexCache = (currentIndexCache + 1) % songListCache.length;
        // 注意：这里只更新索引，实际播放需要先获取URL，所以通过 AppStorage 通知 UI 层处理
        AppStorage.setOrCreate<number>('playRequestIndex', currentIndexCache);
    }

    playPrev(): void {
        if (songListCache.length === 0) return;
        currentIndexCache = (currentIndexCache - 1 + songListCache.length) % songListCache.length;
        AppStorage.setOrCreate<number>('playRequestIndex', currentIndexCache);
    }

    getCurrentIndex(): number {
        return currentIndexCache;
    }

    getSongList(): Song[] {
        return songListCache;
    }

    stop(): void {
        if (avPlayerInstance) {
            avPlayerInstance.stop();
            AppStorage.set<boolean>('isPlaying', false);
            AppStorage.set<Song | null>('currentSong', null);
        }
    }
}
