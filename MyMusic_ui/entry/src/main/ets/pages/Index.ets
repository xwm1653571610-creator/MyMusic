import router from '@ohos.router';
import { PreferenceUtil } from '../utils/PreferenceUtil';
import { HttpUtil } from '../utils/HttpUtil';
import { PlayerManager } from '../managers/PlayerManager';

@Entry
@Component
struct Index {
    @State showText: boolean = false;

    aboutToAppear(): void {
        // 初始化播放器单例
        PlayerManager.getInstance();

        // 延迟显示文字动画
        setTimeout((): void => {
            this.showText = true;
        }, 300);

        // 1.5 秒后自动检测登录状态并跳转
        setTimeout((): void => {
            this.checkLogin();
        }, 1800);
    }

    async checkLogin(): Promise<void> {
        let token = await PreferenceUtil.get(getContext(this), 'token', '') as string;
        let userId = await PreferenceUtil.get(getContext(this), 'userId', '0') as string;

        if (token && userId !== '0') {
            HttpUtil.setToken(token);
            AppStorage.setOrCreate<number>('userId', parseInt(userId));
            router.replaceUrl({ url: 'pages/Main' });
        } else {
            router.replaceUrl({ url: 'pages/Login' });
        }
    }

    build() {
        Column() {
            Column({ space: 15 }) {
                Text('♪')
                    .fontSize(80)
                    .fontColor('#007DFF')

                Text('MyMusic')
                    .fontSize(44)
                    .fontWeight(FontWeight.Bolder)
                    .fontColor('#FFFFFF')

                Text('发现你的下一首心动')
                    .fontSize(16)
                    .fontColor('#888888')
                    .margin({ top: 5 })
            }
            .opacity(this.showText ? 1.0 : 0.0)
            .animation({ duration: 800 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#0D0D0D')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
    }
}