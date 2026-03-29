import preferences from '@ohos.data.preferences';

const PREF_NAME = 'MyMusicStore'; // 本地数据库的文件名

export class PreferenceUtil {
    /**
     * 存入数据
     */
    static async put(context: Context, key: string, value: preferences.ValueType): Promise<void> {
        try {
            let pref = await preferences.getPreferences(context, PREF_NAME);
            await pref.put(key, value);
            await pref.flush(); // 将数据持久化到本地磁盘
        } catch (err) {
            console.error('保存首选项失败:', JSON.stringify(err));
        }
    }

    /**
     * 读取数据
     */
    static async get(context: Context, key: string, defaultValue: preferences.ValueType): Promise<preferences.ValueType> {
        try {
            let pref = await preferences.getPreferences(context, PREF_NAME);
            return await pref.get(key, defaultValue);
        } catch (err) {
            console.error('读取首选项失败:', JSON.stringify(err));
            return defaultValue;
        }
    }

    /**
     * 删除数据 (用于退出登录)
     */
    static async delete(context: Context, key: string): Promise<void> {
        try {
            let pref = await preferences.getPreferences(context, PREF_NAME);
            await pref.delete(key);
            await pref.flush();
        } catch (err) {
            console.error('删除首选项失败:', JSON.stringify(err));
        }
    }
}