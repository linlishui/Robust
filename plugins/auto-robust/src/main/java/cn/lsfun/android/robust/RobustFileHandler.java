package cn.lsfun.android.robust;

import org.gradle.api.Project;
import org.gradle.api.Task;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;

public class RobustFileHandler {

    public static void setupTaskExecution(Project project) {
        project.afterEvaluate(proj -> {
            project.getGradle().getTaskGraph().whenReady(taskGraph -> {
                for (Task task : taskGraph.getAllTasks()) {
                    if (task.getName().startsWith("assemble") && task.getName().endsWith("Release")) {
                        setupTaskCopyAction(project, task);
                        break;
                    }
                }
            });
        });
    }

    private static void setupTaskCopyAction(Project project, Task assembleReleaseTask) {
        String variantName = extractVariantName(assembleReleaseTask.getName());
        if (variantName == null || variantName.isEmpty()) {
            project.getLogger().lifecycle(Constants.LOG_PREFIX + "assembleReleaseTask任务不存在有效的目录");
            return;
        }
        project.getLogger().lifecycle(Constants.LOG_PREFIX + "检测到assembleRelease任务，将在构建完成后拷贝robust相关文件");
        assembleReleaseTask.doLast(task -> {
            try {
                copyFilesToRobustDir(project, variantName);
            } catch (Exception e) {
                project.getLogger().error(Constants.LOG_PREFIX + "拷贝robust相关文件失败: " + e.getMessage(), e);
            }
        });
    }

    private static void copyFilesToRobustDir(Project project, String variantName) throws IOException {
        // 创建robust目标目录
        File robustDir = new File(project.getProjectDir() + File.separator + "robust");
        robustDir.mkdirs();

        // 拷贝 mapping.txt
        String mappingChildPath = "outputs" + File.separator + "mapping" + File.separator + variantName + File.separator + Constants.MAPPING_FILE_NAME;
        File mappingFile = new File(project.getBuildDir(), mappingChildPath);
        copyFile(mappingFile, robustDir);

        // 拷贝 methodsMap.robust、robust.apkhash
        String robustChildPrefix = "outputs" + File.separator + "robust" + File.separator;
        for (String robustFileName : Constants.ROBUST_FILE_NAMES) {
            File robustFile = new File(project.getBuildDir(), robustChildPrefix + robustFileName);
            copyFile(robustFile, robustDir);
        }
    }

    private static String extractVariantName(String taskName) {
        // 从assembleXxxRelease中提取Xxx
        if (taskName.equals("assembleRelease")) {
            return "release";
        }

        String prefix = "assemble";
        String suffix = "Release";

        if (taskName.startsWith(prefix) && taskName.endsWith(suffix)) {
            String middle = taskName.substring(prefix.length(), taskName.length() - suffix.length());
            return middle.isEmpty() ? "release" : middle;
        }

        return null;
    }

    private static void copyFile(File source, File target) throws IOException {
        if (source == null || target == null || !source.exists()) {
            return;
        }

        Files.copy(source.toPath(), new File(target, source.getName()).toPath(), StandardCopyOption.REPLACE_EXISTING);
    }
}
