package cn.lsfun.android.robust;

import org.gradle.api.GradleException;
import org.gradle.api.Plugin;
import org.gradle.api.Project;
import org.gradle.api.logging.LogLevel;

import cn.lsfun.android.robust.config.AutoRobustConfiguration;
import cn.lsfun.android.robust.utils.ConfigurationManager;
import robust.gradle.plugin.AutoPatchTransform;
import robust.gradle.plugin.RobustTransform;

/**
 * 封装robust的[插桩]与[补丁]处理逻辑
 */
public class AutoRobustPlugin implements Plugin<Project> {


    private static ConfigurationManager configManager;
    private static AutoRobustConfiguration robustConfiguration;

    @Override
    public void apply(Project project) {
        if (!project.getPlugins().hasPlugin("com.android.application")) {
            project.getLogger().log(LogLevel.ERROR, "----> AutoRobust 需在 com.android.application 项目使用，当前项目：" + project.getName());
            return;
        }

        try {
            configManager = new ConfigurationManager(project);
            robustConfiguration = AutoRobustConfiguration.build(configManager);
            applyTransformWithConfig(project);
        } catch (Exception e) {
            throw new GradleException(Constants.LOG_PREFIX + "插件初始化失败", e);
        }
    }

    private void applyTransformWithConfig(Project project) {

        Boolean buildPatch = robustConfiguration.buildPatch;

        if (buildPatch == null) {
            project.getLogger().warn(Constants.LOG_PREFIX + "buildPatch 未配置，默认使用插桩模式");
            buildPatch = false;
        }

        project.getLogger().lifecycle(Constants.LOG_PREFIX + "模式： " + (buildPatch ? "补丁" : "插桩"));

        if (buildPatch) {
            project.getPluginManager().apply(AutoPatchTransform.class);
        } else {
            project.getPluginManager().apply(RobustTransform.class);
            RobustFileHandler.setupTaskExecution(project);
        }
    }
}
