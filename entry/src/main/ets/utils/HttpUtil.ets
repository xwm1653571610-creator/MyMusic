import http from '@ohos.net.http';

// 请确保这里的 IP 还是你电脑的局域网真实 IP
const BASE_URL = 'http://192.168.1.100:3000/api';

// 1. 明确声明后端返回的数据结构，T 代表 data 的具体类型
export interface ApiResponse<T> {
    code: number;
    message: string;
    data?: T;
}

export class HttpUtil {
    /**
     * 封装 GET 请求，使用泛型 <T> 替代 any
     */
    static async get<T>(url: string): Promise<ApiResponse<T> | null> {
        const httpRequest = http.createHttp();
        try {
            let response = await httpRequest.request(`${BASE_URL}${url}`, {
                method: http.RequestMethod.GET,
                header: { 'Content-Type': 'application/json' },
                expectDataType: http.HttpDataType.OBJECT
            });
            // 强制类型转换为具体的接口类型
            return response.result as ApiResponse<T>;
        } catch (err) {
            console.error('HTTP GET Error:', JSON.stringify(err));
            return null;
        } finally {
            httpRequest.destroy();
        }
    }

    /**
     * 封装 POST 请求
     * data 参数使用 Object 或 string，替代 object/any
     */
    static async post<T>(url: string, data: Object | string): Promise<ApiResponse<T> | null> {
        const httpRequest = http.createHttp();
        try {
            let response = await httpRequest.request(`${BASE_URL}${url}`, {
                method: http.RequestMethod.POST,
                header: { 'Content-Type': 'application/json' },
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