import router from '@ohos.router';
import { PreferenceUtil } from '../utils/PreferenceUtil';
import { HttpUtil } from '../utils/HttpUtil';

// 需要在 main_pages.json 中配置此页面，并在 entryability 将入口修改为 Splash

@Entry
@Component
struct Splash {
    aboutToAppear() {
        this.verifyLoginStatus();
    }

    async verifyLoginStatus() {
        // 短暂的 Logo 展示延迟，模拟真实的 App 启动冷却
        setTimeout(async () => {
            let token = await PreferenceUtil.get(getContext(this), 'token', '') as string;
            let userId = await PreferenceUtil.get(getContext(this), 'userId', '0') as string;

            if (token && userId !== '0') {
                HttpUtil.setToken(token);
                AppStorage.setOrCreate<number>('userId', parseInt(userId));
                router.replaceUrl({ url: 'pages/Main' });
            } else {
                router.replaceUrl({ url: 'pages/Login' });
            }
        }, 1500);
    }

    build() {
        Column() {
            Image('https://cdn-icons-png.flaticon.com/512/3011/3011236.png')
                .width(120).height(120)
                .margin({ bottom: 20 })
            
            Text('MyMusic PRO')
                .fontSize(36).fontWeight(FontWeight.Bold).fontColor(Color.White)
                
            Text('聆听赛博时代的低语...')
                .fontSize(16).fontColor(Color.Gray).margin({ top: 10 })
        }
        .width('100%').height('100%')
        .backgroundColor('#121212') // 赛博黑底
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
    }
}
