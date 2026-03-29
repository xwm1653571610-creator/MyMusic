import http from '@ohos.net.http';

// 请确保这里的 IP 还是你电脑的局域网真实 IP
export const BASE_URL = 'http://10.159.118.60:3000/api';

export interface ApiResponse<T> {
    code: number;
    message: string;
    data?: T;
}

// ArkTS 禁止在静态方法中使用 this，所以用模块级变量代替静态属性
let bearerToken: string = '';

function getHeaders(): Record<string, string> {
    let headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (bearerToken) {
        headers['Authorization'] = `Bearer ${bearerToken}`;
    }
    return headers;
}

export class HttpUtil {

    static setToken(t: string) {
        bearerToken = t;
    }

    static getToken(): string {
        return bearerToken;
    }

    static async get<T>(url: string): Promise<ApiResponse<T> | null> {
        const httpRequest = http.createHttp();
        try {
            let response = await httpRequest.request(`${BASE_URL}${url}`, {
                method: http.RequestMethod.GET,
                header: getHeaders(),
                expectDataType: http.HttpDataType.OBJECT
            });
            return response.result as ApiResponse<T>;
        } catch (err) {
            console.error('HTTP GET Error:', JSON.stringify(err));
            return null;
        } finally {
            httpRequest.destroy();
        }
    }

    static async post<T>(url: string, data: Object | string): Promise<ApiResponse<T> | null> {
        const httpRequest = http.createHttp();
        try {
            let response = await httpRequest.request(`${BASE_URL}${url}`, {
                method: http.RequestMethod.POST,
                header: getHeaders(),
                extraData: data,
                expectDataType: http.HttpDataType.OBJECT
            });
            return response.result as ApiResponse<T>;
        } catch (err) {
            console.error('HTTP POST Error:', JSON.stringify(err));
            return null;
        } finally {
            httpRequest.destroy();
        }
    }
}