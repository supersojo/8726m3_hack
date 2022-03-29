#  clock control
In mainstream kernel all SOC resources are defined in dts file with physical address.
```
cbus: cbus@c1100000 {
    compatible = "simple-bus";/* for this, it will create platform device for this device node */
    reg = <0xc1100000 0x200000>
    #address-cells = <1>;
    #size-cells = <1>;
    ranges = <0x0 0xc1100000 0x200000>;/* child address space to parent address space with size */)

    hhi: system-controller@4000 {
        compatible = "amlogic,meson-hhi-sysctrl","simple-mfd","syscon";/* first create platform device for this node */
        reg = <0x4000 0x400>;
    };   

    cm: cm@8758 {/* clock measure function */
        compatible = "amlogic,meson-clock-measure";
        reg = <0x8758 0x10>;
    };
};

Once use below function it creates regmap for use dynamically.

syscon_node_to_regmap -> device_node_get_regmap -> of_syscon_register -> regmap_init_mmio

```

## clock measure
```
// ----------------------------
// clock measure (4)
// ----------------------------
#define MSR_CLK_DUTY                               0x21d6
#define MSR_CLK_REG0                               0x21d7
#define MSR_CLK_REG1                               0x21d8
#define MSR_CLK_REG2                               0x21d9
MSR_CLK_REG0
MSR_CLK_REG2

READ_CBUS_REG
WRITE_CBUS_REG
CLEAR_CBUS_REG_MASK
SET_CBUS_REG_MASK
```
We will write such driver below(only export some kernel api to use).

```
static const struct regmap_config syscon_regmap_config = {
    .reg_bits = 32,
    .val_bits = 32,
    .reg_stride = 4,
};
static struct regmap *clock_measure_regmap;
static int meson_clock_measure_probe(struct platform_device *pdev)
{
    struct device *dev = &pdev->dev;
    struct resource res;
    void __iomem *base;
    struct regmap *regmap;

    struct regmap_config syscon_config = syscon_regmap_config;

    if (of_address_to_resource(dev->of_node, 0, &res)) {
        ret = -ENOMEM;
        goto err_map;
    }

    base = of_iomap(dev->of_node, 0);
    if (!base) {
        ret = -ENOMEM;
        goto err_map;
    }   
    syscon_config.name = kasprintf(GFP_KERNEL, "%pOFn@%llx", dev->of_node,
                       (u64)res.start);/* kmalloc */
    syscon_config.reg_stride = 4;
    syscon_config.val_bits = 4 * 8;
    syscon_config.max_register = resource_size(&res) - 4;
    regmap = regmap_init_mmio(NULL, base, &syscon_config);
    kfree(syscon_config.name);
    if (IS_ERR(regmap)) {
        pr_err("regmap init failed\n");
        ret = PTR_ERR(regmap);
        goto err_regmap;
    }

    clock_measure_regmap = regmap;

    return 0;
}
enum {
    MSR_CLK_DUTY = 0,
    MSR_CLK_REG0 = 4,
    MSR_CLK_REG1 = 8,
    MSR_CLK_REG2 = 12,
};
u32 clk_util_clk_msr(u32 clk_mux)
{
    u32 v;

    regmap_write(clock_measure_regmap, MSR_CLK_REG0, 0);

    regmap_clear_bits(clock_measure_regmap, MSR_CLK_REG0, 0xffff);

    regmap_update_bits(clock_measure_regmap, MSR_CLK_REG0, 0xffff, (64 - 1));/* 64 us */

    regmap_clear_bits(clock_measure_regmap, MSR_CLK_REG0, 3<<17);

    regmap_clear_bits(clock_measure_regmap, MSR_CLK_REG0, 1f<<20);

    regmap_set_bits(clock_measure_regmap, MSR_CLK_REG0, clk_mux<<20|1<<16|1<<19);

    regmap_read_poll_timeout(clock_measure_regmap, MSR_CLK_REG0, &v, !(v&(1<<31)), 100/* 100us */, 1000000/* 1s */);

    regmap_clear_bits(clock_measure_regmap, MSR_CLK_REG0, 1<<16);

    regmap_read(clock_measure_regmap, MSR_CLK_REG2, &v);
    v = (v+31)&0xffff;
    v>>=6;

    return v;
}
static const struct of_device_id meson_clock_measure_id[] = { 
    { .compatible = "amlogic, meson-clock-measure" },
    { } 
};
MODULE_DEVICE_TABLE(of, meson_clock_measure_id);

static struct platform_driver meson_clock_measure_driver = { 
    .driver = { 
        .name = "meson-clock-measure",
        .of_match_table = meson_clock_measure_id,
    },  
    .probe = meson_clock_measure_probe,
};
module_platform_driver(meson_clock_measure_driver);

```

## the real clk

