import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { HttpUtil } from '../utils/HttpUtil';
import { PreferenceUtil } from '../utils/PreferenceUtil';

// 显式声明所有接口，避免 arkts-no-untyped-obj-literals
export interface UserInfo {
    id: number;
    username: string;
}

export interface LoginResponseData {
    token: string;
    user: UserInfo;
}

export interface RegisterResponseData {
    userId: number;
}

export interface AuthRequestData {
    username: string;
    password: string;
}

@Entry
@Component
struct Login {
    @State isRegisterMode: boolean = false;
    @State usernameInput: string = '';
    @State passwordInput: string = '';
    @State isLoading: boolean = false;

    async handleAuth(): Promise<void> {
        if (!this.usernameInput || !this.passwordInput) {
            promptAction.showToast({ message: '请输入账号和密码' });
            return;
        }

        this.isLoading = true;
        let requestData: AuthRequestData = {
            username: this.usernameInput,
            password: this.passwordInput
        };

        if (this.isRegisterMode) {
            let res = await HttpUtil.post<RegisterResponseData>('/users/register', requestData);
            this.isLoading = false;
            if (res && res.code === 200) {
                promptAction.showToast({ message: '注册成功，请登录' });
                this.isRegisterMode = false;
            } else {
                promptAction.showToast({ message: res?.message || '注册失败' });
            }
        } else {
            let res = await HttpUtil.post<LoginResponseData>('/users/login', requestData);
            this.isLoading = false;
            if (res && res.code === 200 && res.data) {
                await PreferenceUtil.put(getContext(this), 'token', res.data.token);
                await PreferenceUtil.put(getContext(this), 'userId', res.data.user.id.toString());
                HttpUtil.setToken(res.data.token);
                AppStorage.setOrCreate<number>('userId', res.data.user.id);
                router.replaceUrl({ url: 'pages/Main' });
            } else {
                promptAction.showToast({ message: res?.message || '登录失败' });
            }
        }
    }

    build() {
        Column() {
            // 顶部logo区域
            Column({ space: 10 }) {
                Text('♪')
                    .fontSize(60)
                    .fontColor('#007DFF')

                Text(this.isRegisterMode ? '创建账号' : '欢迎回来')
                    .fontSize(32)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')

                Text(this.isRegisterMode ? '加入 MyMusic 社区' : '登录以继续聆听')
                    .fontSize(14)
                    .fontColor('#888888')
            }
            .margin({ top: 80, bottom: 50 })

            // 输入区域
            Column({ space: 18 }) {
                TextInput({ placeholder: '用户名' })
                    .width('85%')
                    .height(52)
                    .backgroundColor('#1A1A2E')
                    .fontColor('#FFFFFF')
                    .placeholderColor('#666666')
                    .borderRadius(12)
                    .onChange((value: string): void => {
                        this.usernameInput = value;
                    })

                TextInput({ placeholder: '密码' })
                    .type(InputType.Password)
                    .width('85%')
                    .height(52)
                    .backgroundColor('#1A1A2E')
                    .fontColor('#FFFFFF')
                    .placeholderColor('#666666')
                    .borderRadius(12)
                    .onChange((value: string): void => {
                        this.passwordInput = value;
                    })

                Button(this.isLoading ? '请稍候...' : (this.isRegisterMode ? '注 册' : '登 录'))
                    .width('85%')
                    .height(52)
                    .backgroundColor('#007DFF')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .borderRadius(12)
                    .margin({ top: 15 })
                    .enabled(!this.isLoading)
                    .onClick((): void => {
                        this.handleAuth();
                    })

                Text(this.isRegisterMode ? '已有账号？点此登录' : '没有账号？立即注册')
                    .fontColor('#007DFF')
                    .fontSize(14)
                    .padding(15)
                    .onClick((): void => {
                        this.isRegisterMode = !this.isRegisterMode;
                    })
            }
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#0D0D0D')
        .alignItems(HorizontalAlign.Center)
    }
}
