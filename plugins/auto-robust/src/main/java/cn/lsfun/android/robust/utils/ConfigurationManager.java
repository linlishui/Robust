package cn.lsfun.android.robust.utils;


import org.gradle.api.Project;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

public class ConfigurationManager {
    private final Project project;
    private final LocalPropertiesHelper localProps;
    private final Map<String, Object> configCache;

    public ConfigurationManager(Project project) {
        this.project = project;
        this.localProps = new LocalPropertiesHelper(project);
        this.configCache = new ConcurrentHashMap<>();
    }

    // 支持多种来源的配置读取优先级：
    // 1. 系统属性 (-D参数)
    // 2. 环境变量
    // 3. local.properties
    // 4. 默认值
    public <T> T getConfig(String key, Class<T> type, T defaultValue) {
        // 缓存检查
        String cacheKey = key + "_" + type.getSimpleName();
        if (configCache.containsKey(cacheKey)) {
            return type.cast(configCache.get(cacheKey));
        }

        T result = resolveConfigValue(key, type, defaultValue);
        configCache.put(cacheKey, result);

        project.getLogger().debug("配置项 {} = {}", key, result);
        return result;
    }

    @SuppressWarnings("unchecked")
    private <T> T resolveConfigValue(String key, Class<T> type, T defaultValue) {
        // 1. 检查系统属性
        String systemValue = System.getProperty(key);
        if (systemValue != null && !systemValue.trim().isEmpty()) {
            return convertValue(systemValue.trim(), type, defaultValue);
        }

        // 2. 检查环境变量
        String envKey = key.replace(".", "_").toUpperCase();
        String envValue = System.getenv(envKey);
        if (envValue != null && !envValue.trim().isEmpty()) {
            return convertValue(envValue.trim(), type, defaultValue);
        }

        // 3. 检查local.properties
        if (type == String.class) {
            String propValue = localProps.getString(key, (String) defaultValue);
            return (T) propValue;
        } else if (type == Boolean.class) {
            Boolean propValue = localProps.getBoolean(key, (Boolean) defaultValue);
            return (T) propValue;
        } else if (type == Integer.class) {
            Integer propValue = localProps.getInteger(key, (Integer) defaultValue);
            return (T) propValue;
        }

        return defaultValue;
    }

    @SuppressWarnings("unchecked")
    private <T> T convertValue(String value, Class<T> type, T defaultValue) {
        try {
            if (type == String.class) {
                return (T) value;
            } else if (type == Boolean.class) {
                return (T) Boolean.valueOf(value);
            } else if (type == Integer.class) {
                return (T) Integer.valueOf(value);
            }
        } catch (Exception e) {
            project.getLogger().warn("配置值转换失败: {} -> {}, 使用默认值", value, type.getSimpleName());
        }
        return defaultValue;
    }
}
