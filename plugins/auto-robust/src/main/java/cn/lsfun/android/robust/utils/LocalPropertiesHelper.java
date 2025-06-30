package cn.lsfun.android.robust.utils;

import org.gradle.api.Project;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.Properties;

public class LocalPropertiesHelper {
    private static final String LOCAL_PROPERTIES_FILE = "local.properties";
    private final Project project;
    private final Properties properties;

    public LocalPropertiesHelper(Project project) {
        this.project = project;
        this.properties = loadLocalProperties();
    }

    private Properties loadLocalProperties() {
        Properties props = new Properties();

        // 查找local.properties文件
        File localPropsFile = findLocalPropertiesFile();

        if (localPropsFile != null && localPropsFile.exists()) {
            try (FileInputStream fis = new FileInputStream(localPropsFile)) {
                props.load(fis);
                project.getLogger().info("成功加载 local.properties: " + localPropsFile.getAbsolutePath());
            } catch (IOException e) {
                project.getLogger().warn("读取 local.properties 失败: " + e.getMessage());
            }
        } else {
            project.getLogger().warn("未找到 local.properties 文件");
        }

        return props;
    }

    private File findLocalPropertiesFile() {
        // 首先在当前项目目录查找
        File localFile = project.file(LOCAL_PROPERTIES_FILE);
        if (localFile.exists()) {
            return localFile;
        }

        // 在根项目目录查找
        File rootLocalFile = project.getRootProject().file(LOCAL_PROPERTIES_FILE);
        if (rootLocalFile.exists()) {
            return rootLocalFile;
        }

        return null;
    }

    public String getString(String key, String defaultValue) {
        return properties.getProperty(key, defaultValue);
    }

    public Boolean getBoolean(String key, Boolean defaultValue) {
        String value = properties.getProperty(key);
        if (value == null || value.trim().isEmpty()) {
            return defaultValue;
        }
        return Boolean.parseBoolean(value.trim());
    }

    public Integer getInteger(String key, Integer defaultValue) {
        String value = properties.getProperty(key);
        if (value == null || value.trim().isEmpty()) {
            return defaultValue;
        }
        try {
            return Integer.parseInt(value.trim());
        } catch (NumberFormatException e) {
            project.getLogger().warn("配置项 {} 的值 '{}' 不是有效整数，使用默认值 {}", key, value, defaultValue);
            return defaultValue;
        }
    }

    public boolean hasProperty(String key) {
        return properties.containsKey(key);
    }

    public Properties getAllProperties() {
        return new Properties(properties);
    }
}