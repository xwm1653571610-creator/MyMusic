import media from '@ohos.multimedia.media';
import promptAction from '@ohos.promptAction';

export interface Song {
    id: number;
    title: string;
    artist: string;
    cover_url: string;
    audio_url: string;
}

export class PlayerManager {
    private static instance: PlayerManager;
    private avPlayer: media.AVPlayer | null = null;

    private constructor() {
        // AppStorage initialization
        AppStorage.setOrCreate<Song | null>('currentSong', null);
        AppStorage.setOrCreate<boolean>('isPlaying', false);
        AppStorage.setOrCreate<number>('currentTime', 0);
        AppStorage.setOrCreate<number>('totalTime', 0);

        this.initAVPlayer();
    }

    public static getInstance(): PlayerManager {
        if (!PlayerManager.instance) {
            PlayerManager.instance = new PlayerManager();
        }
        return PlayerManager.instance;
    }

    private async initAVPlayer() {
        try {
            this.avPlayer = await media.createAVPlayer();
            this.setAVPlayerCallback();
        } catch (error) {
            console.error('AVPlayer init error', JSON.stringify(error));
        }
    }

    private setAVPlayerCallback() {
        if (!this.avPlayer) return;
        this.avPlayer.on('stateChange', async (state: string) => {
            switch (state) {
                case 'initialized':
                    this.avPlayer?.prepare();
                    break;
                case 'prepared':
                    this.avPlayer?.play();
                    AppStorage.set<boolean>('isPlaying', true);
                    AppStorage.set<number>('totalTime', this.avPlayer?.duration || 0);
                    break;
                case 'playing':
                    AppStorage.set<boolean>('isPlaying', true);
                    break;
                case 'paused':
                case 'completed':
                case 'stopped':
                case 'error':
                    AppStorage.set<boolean>('isPlaying', false);
                    break;
            }
        });

        this.avPlayer.on('durationUpdate', (duration: number) => {
            AppStorage.set<number>('totalTime', duration);
        });

        this.avPlayer.on('timeUpdate', (time: number) => {
            AppStorage.set<number>('currentTime', time);
        });
    }

    public playSong(song: Song) {
        if (!this.avPlayer) return;
        AppStorage.set<Song | null>('currentSong', song);
        
        this.avPlayer.reset().then(() => {
            if (song.audio_url && this.avPlayer) {
                this.avPlayer.url = song.audio_url; 
            } else {
                promptAction.showToast({ message: '此歌曲暂无音频资源' });
            }
        });
    }

    public togglePlay() {
        if (!this.avPlayer) return;
        let isPlaying = AppStorage.get<boolean>('isPlaying');
        if (isPlaying) {
            this.avPlayer.pause();
        } else {
            this.avPlayer.play();
        }
    }

    public seek(timeMs: number) {
        if (!this.avPlayer) return;
        this.avPlayer.seek(timeMs);
    }
    
    public stop() {
        if (this.avPlayer) {
            this.avPlayer.stop();
            AppStorage.set<boolean>('isPlaying', false);
            AppStorage.set<Song | null>('currentSong', null);
        }
    }
}
