import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { HttpUtil } from '../utils/HttpUtil';
import { PreferenceUtil } from '../utils/PreferenceUtil';

export interface UserInfo { id: number; username: string; }
export interface LoginResponseData { token: string; user: UserInfo; }
export interface RegisterResponseData { userId: number; }
export interface AuthRequestData { username?: string; password?: string; }

@Entry
@Component
struct Login {
    @State isRegisterMode: boolean = false;
    @State usernameInput: string = ''; 
    @State passwordInput: string = '';

    async handleAuth() {
        if (!this.usernameInput || !this.passwordInput) {
            promptAction.showToast({ message: '请输入账号密码' });
            return;
        }

        let requestData: AuthRequestData = {
            username: this.usernameInput,
            password: this.passwordInput
        };

        if (this.isRegisterMode) {
            let res = await HttpUtil.post<RegisterResponseData>('/users/register', requestData);
            if (res && res.code === 200) {
                promptAction.showToast({ message: '注册成功，请登录' });
                this.isRegisterMode = false;
            } else {
                promptAction.showToast({ message: res?.message || '注册失败' });
            }
        } else {
            let res = await HttpUtil.post<LoginResponseData>('/users/login', requestData);
            if (res && res.code === 200 && res.data) {
                promptAction.showToast({ message: '登录成功' });
                await PreferenceUtil.put(getContext(this), 'token', res.data.token);
                await PreferenceUtil.put(getContext(this), 'userId', res.data.user.id.toString());
                HttpUtil.setToken(res.data.token);
                AppStorage.setOrCreate<number>('userId', res.data.user.id);
                // 登录成功跃迁到主页
                router.replaceUrl({ url: 'pages/Main' });
            } else {
                promptAction.showToast({ message: res?.message || '登录失败，请检查账号密码' });
            }
        }
    }

    build() {
        Stack({ alignContent: Alignment.Center }) {
            // 背景渐变
            Rect().width('100%').height('100%')
                .linearGradient({
                     angle: 45,
                     colors: [[0x001529, 0.0], [0x00416A, 1.0]]
                 })

            // 玻璃拟态包裹层
            Column({ space: 25 }) {
                Text(this.isRegisterMode ? '创建音乐档案' : '欢迎回到 MyMusic')
                    .fontSize(28).fontWeight(FontWeight.Bolder).fontColor(Color.White)
                    .margin({ top: 30, bottom: 20 })

                TextInput({ placeholder: '账号' })
                    .backgroundColor('rgba(255, 255, 255, 0.15)')
                    .fontColor(Color.White)
                    .placeholderColor('#A0A0A0')
                    .width('85%').height(55)
                    .borderRadius(12)
                    .onChange((value) => { this.usernameInput = value })

                TextInput({ placeholder: '密码' })
                    .type(InputType.Password)
                    .backgroundColor('rgba(255, 255, 255, 0.15)')
                    .fontColor(Color.White)
                    .placeholderColor('#A0A0A0')
                    .width('85%').height(55)
                    .borderRadius(12)
                    .onChange((value) => { this.passwordInput = value })

                Button(this.isRegisterMode ? '立即开通' : '登 录')
                    .width('85%').height(55)
                    .backgroundColor('#007DFF')
                    .fontSize(18).fontWeight(FontWeight.Bold)
                    .margin({ top: 20 })
                    .onClick(() => { this.handleAuth() })

                Text(this.isRegisterMode ? '已有账号？点此登录' : '没有账号？立即注册')
                    .fontColor('#40A9FF').fontSize(14)
                    .padding(20)
                    .onClick(() => { this.isRegisterMode = !this.isRegisterMode; })
            }
            .width('85%')
            .padding({ bottom: 40 })
            .backgroundColor('rgba(0, 0, 0, 0.35)') // 半透明毛玻璃底色
            .borderRadius(20)
            .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.5)', offsetY: 10 })
            .backdropBlur(25) // 高级玻璃拟态特效
        }
        .width('100%').height('100%')
    }
}
