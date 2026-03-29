import http from '@ohos.net.http';

// 请确保这里的 IP 还是你电脑的局域网真实 IP
export const BASE_URL = 'http://10.159.118.60:3000/api';

export interface ApiResponse<T> {
    code: number;
    message: string;
    data?: T;
}

export class HttpUtil {
    // 内存里维护一个 token 变量，避免每次请求都去读耗时的底层 Preference
    private static bearerToken: string = '';

    static setToken(t: string) {
        this.bearerToken = t;
    }

    static getToken() {
        return this.bearerToken;
    }

    private static getHeaders(): Record<string, string> {
        let headers: Record<string, string> = { 'Content-Type': 'application/json' };
        if (this.bearerToken) {
            headers['Authorization'] = `Bearer ${this.bearerToken}`;
        }
        return headers;
    }

    static async get<T>(url: string): Promise<ApiResponse<T> | null> {
        const httpRequest = http.createHttp();
        try {
            let response = await httpRequest.request(`${BASE_URL}${url}`, {
                method: http.RequestMethod.GET,
                header: this.getHeaders(),
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
                header: this.getHeaders(),
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