package cn.lsfun.android.robust.config;


import cn.lsfun.android.robust.Constants;
import cn.lsfun.android.robust.utils.ConfigurationManager;

public class AutoRobustConfiguration {


    public final Boolean buildPatch;

    public AutoRobustConfiguration(Boolean buildPatch) {
        this.buildPatch = buildPatch;
    }

    public static AutoRobustConfiguration build(ConfigurationManager configManager) {
        return new AutoRobustConfiguration(
                configManager.getConfig(Constants.CONFIG_BUILD_PATCH, Boolean.class, false)
        );
    }
}
