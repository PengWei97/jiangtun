# ==========================================================
# xxx.i
#
# Phase 2 baseline for a 2D nondimensional transient PIMPLE
# single-wafer conjugate heat transfer (CHT) model with
# Boussinesq buoyancy and wall heat-flux heating.
#
# Goals of this version:
#   1) stable and reproducible baseline,
#   2) clean naming / outputs,
#   3) conservative but not overly slow time stepping,
#   4) slightly stronger interface consistency monitoring setup.
#
# Physics in Phase 2:
#   - incompressible forced + buoyancy-assisted convection in fluid region,
#   - transient heat advection-diffusion in fluid,
#   - transient heat conduction in wafer,
#   - Robin-Robin CHT coupling at the fluid-solid interface,
#   - Boussinesq buoyancy in the vertical momentum equation,
#   - prescribed uniform wall heat flux on top and bottom walls.
# ==========================================================

base_name = 'step3a_xxx'

# -----------------------------
# nondimensional groups
# -----------------------------
Re = 50
Pr = 0.7
mu_fluid = ${fparse 1.0/Re}
alpha_fluid = ${fparse 1.0/(Re*Pr)}

# solid/fluid thermal-property ratios
k_wafer = 0.20
k_quartz_tube = 0.08
rhoCp_fluid = 1.0
rhoCp_wafer = 5.0
rhoCp_quartz_tube = 2.5
wafer_cap_ratio = ${fparse rhoCp_wafer / rhoCp_fluid}
tube_cap_ratio = ${fparse rhoCp_quartz_tube / rhoCp_fluid}

# numerical controls
advected_interp_method = 'average'
cht_h_scale = 1.0

# -----------------------------
# wall heating controls
# -----------------------------
# Positive values correspond to positive n·(alpha grad T), which injects
# heat into the domain for both the top and bottom horizontal walls.
wall_heat_flux_top = 0.1
wall_heat_flux_bottom = 0.1

# -----------------------------
# Boussinesq buoyancy controls
# -----------------------------
# Nondimensional strategy:
#   buoyancy ~ Ri * (T - T_ref) in the vertical momentum equation
# where Ri is a Richardson-like control parameter.
#
# Start with a moderate value for stability, then tune upward if
# buoyancy effects are too weak.
rho_bouss = 1.0
Ri_bouss = 1.0
T_ref_bouss = 0.0
gvec_y = -1.0

# -----------------------------
# surface-to-surface radiation controls
# -----------------------------
# sigma_sb = 5.670374419e-8
eps_tube_top = 0.80
eps_tube_bottom = 0.80
eps_wafer_lr = 0.70
rad_k_tube = ${k_quartz_tube}
rad_k_wafer = ${k_wafer}

[Mesh]
  [box]
    type = CartesianMeshGenerator
    dim = 2

    # x direction:
    # left far field / pre-wafer refined / wafer / post-wafer refined / right far field
    dx = '2.20 0.295 0.01 0.295 2.20'
    ix = '70 40 10 40 70'

    # y direction:
    # bottom tube / lower fluid / wafer span / upper fluid / top tube
    dy = '0.06 0.25 1.0 0.25 0.06'
    iy = '10 12 50 12 10'

    # --------------------------------------------------
    # temporary subdomain layout for interface creation
    #
    # row 1 (bottom): bottom quartz tube   -> 4
    # row 2         : lower fluid          -> 6
    # row 3         : side fluid / wafer   -> 1 1 2 1 1
    # row 4         : upper fluid          -> 5
    # row 5 (top)   : top quartz tube      -> 3
    #
    # temporary IDs:
    #   1 = side fluid
    #   2 = wafer
    #   3 = top quartz tube
    #   4 = bottom quartz tube
    #   5 = upper fluid
    #   6 = lower fluid
    # --------------------------------------------------
    subdomain_id = '4 4 4 4 4
                    6 6 6 6 6
                    1 1 2 1 1
                    5 5 5 5 5
                    3 3 3 3 3'
  []

  # ==================================================
  # 1) Create fine interfaces FIRST (for radiation / diagnostics)
  # ==================================================

  # wafer left/right main faces: side fluid (1) <-> wafer (2)
  [wafer_lr_interface_gen]
    type = SideSetsBetweenSubdomainsGenerator
    input = box
    primary_block = 1
    paired_block = 2
    new_boundary = wafer_lr_interface
  []

  # wafer top short edge: upper fluid (5) <-> wafer (2)
  [wafer_top_interface_gen]
    type = SideSetsBetweenSubdomainsGenerator
    input = wafer_lr_interface_gen
    primary_block = 5
    paired_block = 2
    new_boundary = wafer_top_interface
  []

  # wafer bottom short edge: lower fluid (6) <-> wafer (2)
  [wafer_bottom_interface_gen]
    type = SideSetsBetweenSubdomainsGenerator
    input = wafer_top_interface_gen
    primary_block = 6
    paired_block = 2
    new_boundary = wafer_bottom_interface
  []

  # top tube inner wall: upper fluid (5) <-> top quartz (3)
  [tube_top_interface_gen]
    type = SideSetsBetweenSubdomainsGenerator
    input = wafer_bottom_interface_gen
    primary_block = 5
    paired_block = 3
    new_boundary = tube_top_interface
  []

  # bottom tube inner wall: lower fluid (6) <-> bottom quartz (4)
  [tube_bottom_interface_gen]
    type = SideSetsBetweenSubdomainsGenerator
    input = tube_top_interface_gen
    primary_block = 6
    paired_block = 4
    new_boundary = tube_bottom_interface
  []

  # ==================================================
  # 2) Merge temporary blocks back to final physical blocks
  # ==================================================

  [merge_upper_fluid]
    type = RenameBlockGenerator
    input = tube_bottom_interface_gen
    old_block = 5
    new_block = 1
  []
  
  [merge_lower_fluid]
    type = RenameBlockGenerator
    input = merge_upper_fluid
    old_block = 6
    new_block = 1
  []
  
  [merge_bottom_tube]
    type = RenameBlockGenerator
    input = merge_lower_fluid
    old_block = 4
    new_block = 3
  []

  # ==================================================
  # 3) Keep fine interfaces directly for CHT / radiation
  #    (do not reconstruct merged total interfaces)
  # ==================================================

  [./break_sides] # right_to_1, right_to_3
    type = BreakBoundaryOnSubdomainGenerator
    boundaries = 'right left'
    input = merge_bottom_tube
  [../]

  # ==================================================
  # 4) Split left/right external boundaries by subdomain
  #    (useful for fluid inlet/outlet vs quartz side walls)
  # ==================================================
  [delete_others]
    type = BoundaryDeletionGenerator
    input = 'break_sides'
    boundary_names = 'right left'
  []

  parallel_type = replicated
[]

[Problem]
  linear_sys_names = 'u_system v_system pressure_system energy_system solid_energy_system'
  previous_nl_solution_required = true
[]

[UserObjects]
  [rc]
    type = RhieChowMassFlux
    u = vel_x
    v = vel_y
    pressure = pressure
    rho = 1.0
    block = 1
    p_diffusion_kernel = p_diffusion
  []

  [gray_lambert]
    type = ViewFactorObjectSurfaceRadiation
    boundary = 'tube_top_interface tube_bottom_interface wafer_lr_interface'
    emissivity = '${eps_tube_top} ${eps_tube_bottom} ${eps_wafer_lr}'
    temperature = T_solid
    view_factor_object_name = view_factor
    execute_on = 'LINEAR TIMESTEP_BEGIN TIMESTEP_END NONLINEAR'
  []

  [view_factor]
    type = UnobstructedPlanarViewFactor
    boundary = 'tube_top_interface tube_bottom_interface wafer_lr_interface'
    normalize_view_factor = true
    execute_on = 'INITIAL'
  []
[]

[Variables]
  [vel_x]
    type = MooseLinearVariableFVReal
    block = 1
    initial_condition = 1.0
    solver_sys = u_system
  []
  [vel_y]
    type = MooseLinearVariableFVReal
    block = 1
    initial_condition = 0.0
    solver_sys = v_system
  []
  [pressure]
    type = MooseLinearVariableFVReal
    block = 1
    initial_condition = 0.0
    solver_sys = pressure_system
  []
  [T_fluid]
    type = MooseLinearVariableFVReal
    block = 1
    initial_condition = 0.0
    solver_sys = energy_system
  []
  [T_solid]
    type = MooseLinearVariableFVReal
    block = '2 3'
    initial_condition = 0.0
    solver_sys = solid_energy_system
  []
[]

[LinearFVKernels]
  # -----------------------------
  # fluid momentum
  # -----------------------------
  [u_time]
    type = LinearFVTimeDerivative
    variable = vel_x
    factor = 1.0
  []
  [v_time]
    type = LinearFVTimeDerivative
    variable = vel_y
    factor = 1.0
  []

  [u_advection_stress]
    type = LinearWCNSFVMomentumFlux
    variable = vel_x
    advected_interp_method = ${advected_interp_method}
    mu = ${mu_fluid}
    u = vel_x
    v = vel_y
    momentum_component = 'x'
    rhie_chow_user_object = 'rc'
    use_nonorthogonal_correction = false
  []
  [v_advection_stress]
    type = LinearWCNSFVMomentumFlux
    variable = vel_y
    advected_interp_method = ${advected_interp_method}
    mu = ${mu_fluid}
    u = vel_x
    v = vel_y
    momentum_component = 'y'
    rhie_chow_user_object = 'rc'
    use_nonorthogonal_correction = false
  []

  [u_pressure]
    type = LinearFVMomentumPressure
    variable = vel_x
    pressure = pressure
    momentum_component = 'x'
  []
  [v_pressure]
    type = LinearFVMomentumPressure
    variable = vel_y
    pressure = pressure
    momentum_component = 'y'
  []

  [v_buoyancy]
    type = LinearFVMomentumBoussinesq
    variable = vel_y
    block = 1
    rho = ${rho_bouss}
    gravity = '0 ${gvec_y} 0'
    alpha_name = ${Ri_bouss}
    ref_temperature = ${T_ref_bouss}
    T_fluid = T_fluid
    momentum_component = 'y'
  []

  # -----------------------------
  # pressure correction
  # -----------------------------
  [p_diffusion]
    type = LinearFVAnisotropicDiffusion
    variable = pressure
    diffusion_tensor = Ainv
    use_nonorthogonal_correction = false
  []
  [HbyA_divergence]
    type = LinearFVDivergence
    variable = pressure
    face_flux = HbyA
    force_boundary_execution = true
  []

  # -----------------------------
  # fluid energy
  # -----------------------------
  [fluid_h_time]
    type = LinearFVTimeDerivative
    variable = T_fluid
    factor = 1.0
  []
  [fluid_h_advection]
    type = LinearFVEnergyAdvection
    variable = T_fluid
    advected_quantity = temperature
    cp = 1.0
    advected_interp_method = ${advected_interp_method}
    rhie_chow_user_object = 'rc'
  []
  [fluid_conduction]
    type = LinearFVDiffusion
    variable = T_fluid
    diffusion_coeff = ${alpha_fluid}
    use_nonorthogonal_correction = false
  []

  # -----------------------------
  # solid energy
  # -----------------------------
  [solid_h_time_wafer]
    type = LinearFVTimeDerivative
    block = '2'
    variable = T_solid
    factor = ${wafer_cap_ratio}
  []
  [solid_h_time_tube]
    type = LinearFVTimeDerivative
    block = '3'
    variable = T_solid
    factor = ${tube_cap_ratio}
  []

  [solid_conduction]
    type = LinearFVDiffusion
    block = '2 3'
    variable = T_solid
    diffusion_coeff = thermal_conductivity_solid
    use_nonorthogonal_correction = false
  []
[]

[FunctorMaterials]
  [solid_conductivity_wafer]
    type = GenericFunctorMaterial
    block = 2
    prop_names = 'thermal_conductivity_solid'
    prop_values = '${k_wafer}'
  []

  [solid_conductivity_tube]
    type = GenericFunctorMaterial
    block = 3
    prop_names = 'thermal_conductivity_solid'
    prop_values = '${k_quartz_tube}'
  []

  [fluid_dummy_functor]
    type = GenericFunctorMaterial
    block = 1
    prop_names = 'dummy_functor_prop'
    prop_values = '0'
  []
[]

[LinearFVBCs]
  # -----------------------------
  # inlet
  # -----------------------------
  [inlet_u]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_x
    boundary = left_to_1
    functor = 1.0
  []
  [inlet_v]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_y
    boundary = left_to_1
    functor = 0.0
  []
  [inlet_T]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = T_fluid
    boundary = left_to_1
    functor = 0.0
  []

  # -----------------------------
  # outer walls + wafer no-slip
  # -----------------------------
  [walls_u]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_x
    boundary = 'wafer_lr_interface wafer_top_interface wafer_bottom_interface tube_top_interface tube_bottom_interface'
    functor = 0.0
  []
  [walls_v]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_y
    boundary = 'wafer_lr_interface wafer_top_interface wafer_bottom_interface tube_top_interface tube_bottom_interface'
    functor = 0.0
  []

  [top_wall_heat_flux]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    variable = T_solid
    boundary = top
    functor = ${wall_heat_flux_top}
    diffusion_coeff = ${k_quartz_tube}
  []

  [bottom_wall_heat_flux]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    variable = T_solid
    boundary = bottom
    functor = ${wall_heat_flux_bottom}
    diffusion_coeff = ${k_quartz_tube}
  []

  # -----------------------------
  # outlet
  # -----------------------------
  [outlet_p]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = pressure
    boundary = right_to_1
    functor = 0.0
  []
  [outlet_u]
    type = LinearFVAdvectionDiffusionOutflowBC
    variable = vel_x
    boundary = right_to_1
  []
  [outlet_v]
    type = LinearFVAdvectionDiffusionOutflowBC
    variable = vel_y
    boundary = right_to_1
  []
  [outlet_T]
    type = LinearFVAdvectionDiffusionOutflowBC
    variable = T_fluid
    boundary = right_to_1
  []

  # -----------------------------
  # fluid-solid CHT interface
  # -----------------------------
  [fluid_wafer_lr_interface_temperature]
    type = LinearFVRobinCHTBC
    variable = T_fluid
    boundary = wafer_lr_interface
    h = ${cht_h_scale}
    incoming_flux = heat_flux_to_fluid_wafer_lr_interface
    surface_temperature = interface_temperature_solid_wafer_lr_interface
    thermal_conductivity = ${alpha_fluid}
  []
  [fluid_wafer_top_interface_temperature]
    type = LinearFVRobinCHTBC
    variable = T_fluid
    boundary = wafer_top_interface
    h = ${cht_h_scale}
    incoming_flux = heat_flux_to_fluid_wafer_top_interface
    surface_temperature = interface_temperature_solid_wafer_top_interface
    thermal_conductivity = ${alpha_fluid}
  []
  [fluid_wafer_bottom_interface_temperature]
    type = LinearFVRobinCHTBC
    variable = T_fluid
    boundary = wafer_bottom_interface
    h = ${cht_h_scale}
    incoming_flux = heat_flux_to_fluid_wafer_bottom_interface
    surface_temperature = interface_temperature_solid_wafer_bottom_interface
    thermal_conductivity = ${alpha_fluid}
  []
  [solid_wafer_lr_interface_flux]
    type = LinearFVRobinCHTBC
    variable = T_solid
    boundary = wafer_lr_interface
    h = ${cht_h_scale}
    incoming_flux = heat_flux_to_solid_wafer_lr_interface
    surface_temperature = interface_temperature_fluid_wafer_lr_interface
    thermal_conductivity = ${k_wafer}
  []
  [solid_wafer_top_interface_flux]
    type = LinearFVRobinCHTBC
    variable = T_solid
    boundary = wafer_top_interface
    h = ${cht_h_scale}
    incoming_flux = heat_flux_to_solid_wafer_top_interface
    surface_temperature = interface_temperature_fluid_wafer_top_interface
    thermal_conductivity = ${k_wafer}
  []
  [solid_wafer_bottom_interface_flux]
    type = LinearFVRobinCHTBC
    variable = T_solid
    boundary = wafer_bottom_interface
    h = ${cht_h_scale}
    incoming_flux = heat_flux_to_solid_wafer_bottom_interface
    surface_temperature = interface_temperature_fluid_wafer_bottom_interface
    thermal_conductivity = ${k_wafer}
  []

  # -----------------------------
  # fluid-solid CHT interface
  # -----------------------------
  [fluid_tube_top_interface_temperature]
    type = LinearFVRobinCHTBC
    variable = T_fluid
    boundary = tube_top_interface
    h = ${cht_h_scale}
    incoming_flux = heat_flux_to_fluid_tube_top_interface
    surface_temperature = interface_temperature_solid_tube_top_interface
    thermal_conductivity = ${alpha_fluid}
  []
  [fluid_tube_bottom_interface_temperature]
    type = LinearFVRobinCHTBC
    variable = T_fluid
    boundary = tube_bottom_interface
    h = ${cht_h_scale}
    incoming_flux = heat_flux_to_fluid_tube_bottom_interface
    surface_temperature = interface_temperature_solid_tube_bottom_interface
    thermal_conductivity = ${alpha_fluid}
  []
  [solid_tube_top_interface_flux]
    type = LinearFVRobinCHTBC
    variable = T_solid
    boundary = tube_top_interface
    h = ${cht_h_scale}
    incoming_flux = heat_flux_to_solid_tube_top_interface
    surface_temperature = interface_temperature_fluid_tube_top_interface
    thermal_conductivity = ${k_quartz_tube}
  []
  [solid_tube_bottom_interface_flux]
    type = LinearFVRobinCHTBC
    variable = T_solid
    boundary = tube_bottom_interface
    h = ${cht_h_scale}
    incoming_flux = heat_flux_to_solid_tube_bottom_interface
    surface_temperature = interface_temperature_fluid_tube_bottom_interface
    thermal_conductivity = ${k_quartz_tube}
  []

  [tube_radiation]
    type = LinearFVGrayLambert
    variable = T_solid
    temperature_radiation = T_solid
    coeff_diffusion = ${rad_k_tube}
    surface_radiation_object_name = gray_lambert
    boundary = 'tube_top_interface tube_bottom_interface'
  []

  [wafer_radiation]
    type = LinearFVGrayLambert
    variable = T_solid
    temperature_radiation = T_solid
    coeff_diffusion = ${rad_k_wafer}
    surface_radiation_object_name = gray_lambert
    boundary = 'wafer_lr_interface'
  []  
[]

[AuxVariables]
  [T_total]
    order = CONSTANT
    family = MONOMIAL
  []
[]

[AuxKernels]
  [T_in_fluid]
    type = FunctorAux
    variable = T_total
    block = 1
    functor = T_fluid
  []
  [T_in_solid]
    type = FunctorAux
    variable = T_total
    block = '2 3'
    functor = T_solid
  []
[]

[Executioner]
  type = PIMPLE

  momentum_l_abs_tol = 1e-10
  pressure_l_abs_tol = 1e-10
  energy_l_abs_tol = 1e-10
  solid_energy_l_abs_tol = 1e-10

  momentum_l_tol = 0
  pressure_l_tol = 0
  energy_l_tol = 0
  solid_energy_l_tol = 0

  rhie_chow_user_object = 'rc'
  momentum_systems = 'u_system v_system'
  pressure_system = 'pressure_system'
  energy_system = 'energy_system'
  solid_energy_system = 'solid_energy_system'

  momentum_equation_relaxation = 0.5
  pressure_variable_relaxation = 0.2
  energy_equation_relaxation = 0.7

  num_iterations = 50

  pressure_absolute_tolerance = 1e-8
  momentum_absolute_tolerance = 1e-8
  energy_absolute_tolerance = 1e-8
  solid_energy_absolute_tolerance = 2e-5

  pin_pressure = false

  # CHT fixed-point controls
  cht_interfaces = 'wafer_lr_interface wafer_top_interface wafer_bottom_interface tube_top_interface tube_bottom_interface'
  cht_solid_flux_relaxation = '0.25 0.25 0.25 0.25 0.25'
  cht_fluid_flux_relaxation = '0.25 0.25 0.25 0.25 0.25'
  cht_solid_temperature_relaxation = '0.40 0.40 0.40 0.40 0.40'
  cht_fluid_temperature_relaxation = '0.40 0.40 0.40 0.40 0.40'
  max_cht_fpi = 5

  print_fields = false
  continue_on_max_its = true

  end_time = 10
  # num_steps = 10
  num_piso_iterations = 0

  dtmax = 1.0e-2
  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 1.0e-5
    optimal_iterations = 4
    iteration_window = 2
    growth_factor = 1.2
    cutback_factor = 0.5
  []

  pressure_petsc_options_iname = '-ksp_type -pc_type -pc_hypre_type'
  pressure_petsc_options_value = 'cg hypre boomeramg'

  energy_petsc_options_iname = '-ksp_type -pc_type -pc_hypre_type'
  energy_petsc_options_value = 'gmres hypre boomeramg'

  solid_energy_petsc_options_iname = '-ksp_type -pc_type -pc_hypre_type'
  solid_energy_petsc_options_value = 'cg hypre boomeramg'
[]

[Postprocessors]

  # ==================================================
  # 1) 时间步与计算性能监控
  # ==================================================
  # dt：当前时间步长，用于判断时间推进是否稳定/自适应是否合理
  [dt]
    type = TimestepSize
  []

  # run_time：累计计算时间（性能监控）
  [run_time]
    type = PerfGraphData
    section_name = 'Root'
    data_type = total
  []

  # # ==================================================
  # # 2) 各区域温度统计（核心结果）
  # # ==================================================
  # # --- wafer（晶圆）温度 ---
  # # 平均温度：反映整体加热水平
  # [wafer_T_avg]
  #   type = ElementAverageValue
  #   variable = T_solid
  #   block = 2
  # []

  # # 最大温度：判断是否存在局部过热
  # [wafer_T_max]
  #   type = ElementExtremeValue
  #   variable = T_solid
  #   block = 2
  #   value_type = max
  # []

  # # 最小温度：判断冷点
  # [wafer_T_min]
  #   type = ElementExtremeValue
  #   variable = T_solid
  #   block = 2
  #   value_type = min
  # []

  # # 温差：评价晶圆温度均匀性（最关键指标之一）
  # [wafer_delta_T]
  #   type = ParsedPostprocessor
  #   pp_names = 'wafer_T_max wafer_T_min'
  #   pp_symbols = 'tmax tmin'
  #   expression = 'tmax - tmin'
  # []

  # # --- quartz tube（石英壁）温度 ---
  # # 平均温度：反映石英壁整体热状态
  # [tube_T_avg]
  #   type = ElementAverageValue
  #   variable = T_solid
  #   block = 3
  # []

  # # 极值温度：判断石英壁温度分布范围
  # [tube_T_max]
  #   type = ElementExtremeValue
  #   variable = T_solid
  #   block = 3
  #   value_type = max
  # []
  # [tube_T_min]
  #   type = ElementExtremeValue
  #   variable = T_solid
  #   block = 3
  #   value_type = min
  # []

  # # --- fluid（气体）温度 ---
  # # 平均温度：反映气体整体热水平
  # [fluid_T_avg]
  #   type = ElementAverageValue
  #   variable = T_fluid
  #   block = 1
  # []

  # # 极值温度：判断气体是否存在明显温度梯度或局部热点
  # [fluid_T_max]
  #   type = ElementExtremeValue
  #   variable = T_fluid
  #   block = 1
  #   value_type = max
  # []
  # [fluid_T_min]
  #   type = ElementExtremeValue
  #   variable = T_fluid
  #   block = 1
  #   value_type = min
  # []

  # # ==================================================
  # # 3) 流动入口/出口诊断（流动与传热耦合）
  # # ==================================================
  # # --- 温度 ---
  # # 入口温度：用于验证边界条件是否稳定
  # [inlet_T_avg]
  #   type = SideAverageValue
  #   variable = T_fluid
  #   boundary = left_to_1
  # []

  # # 出口温度：反映气体带走热量的能力（关键热平衡指标）
  # [outlet_T_avg]
  #   type = SideAverageValue
  #   variable = T_fluid
  #   boundary = right_to_1
  # []

  # # --- 压力 ---
  # # 入口平均压力
  # [inlet_p_avg]
  #   type = SideAverageValue
  #   variable = pressure
  #   boundary = left_to_1
  # []

  # # 出口平均压力
  # [outlet_p_avg]
  #   type = SideAverageValue
  #   variable = pressure
  #   boundary = right_to_1
  # []

  # # 压降：评价流动阻力（影响对流换热能力）
  # [delta_p_inlet_minus_outlet]
  #   type = DifferencePostprocessor
  #   value1 = inlet_p_avg
  #   value2 = outlet_p_avg
  # []

  # # ==================================================
  # # 4) 石英外壁温度（边界状态）
  # # ==================================================
  # # 上外壁温度：对应外部加热区域
  # [top_outer_tube_T_avg]
  #   type = SideAverageValue
  #   variable = T_solid
  #   boundary = top
  # []

  # # 下外壁温度
  # [bottom_outer_tube_T_avg]
  #   type = SideAverageValue
  #   variable = T_solid
  #   boundary = bottom
  # []

  # # 上下外壁温差：判断加热是否对称
  # [outer_tube_delta_T]
  #   type = ParsedPostprocessor
  #   pp_names = 'top_outer_tube_T_avg bottom_outer_tube_T_avg'
  #   pp_symbols = 'Ttop Tbot'
  #   expression = 'Ttop - Tbot'
  # []

  # # ==================================================
  # # 5) 外壁输入热流（能量输入）
  # # ==================================================
  # # --- 平均热流密度 ---
  # # 上外壁热流密度（单位面积）
  # [top_wall_heat_in_avg]
  #   type = SideDiffusiveFluxAverage
  #   variable = T_solid
  #   boundary = top
  #   functor_diffusivity = ${k_quartz_tube}
  # []

  # # 下外壁热流密度
  # [bottom_wall_heat_in_avg]
  #   type = SideDiffusiveFluxAverage
  #   variable = T_solid
  #   boundary = bottom
  #   functor_diffusivity = ${k_quartz_tube}
  # []

  # # --- 总热流（积分）---
  # # 上外壁总输入功率
  # [top_wall_heat_in_integral]
  #   type = SideDiffusiveFluxIntegral
  #   variable = T_solid
  #   boundary = top
  #   functor_diffusivity = ${k_quartz_tube}
  # []

  # # 下外壁总输入功率
  # [bottom_wall_heat_in_integral]
  #   type = SideDiffusiveFluxIntegral
  #   variable = T_solid
  #   boundary = bottom
  #   functor_diffusivity = ${k_quartz_tube}
  # []

  # # 总输入热量（系统能量输入）
  # [total_wall_heat_in_integral]
  #   type = ParsedPostprocessor
  #   pp_names = 'top_wall_heat_in_integral bottom_wall_heat_in_integral'
  #   pp_symbols = 'qtop qbot'
  #   expression = 'qtop + qbot'
  # []
[]

[Outputs]
  [my_exodus]
    type = Exodus
    file_base = ./ex_${base_name}/out_${base_name}
    time_step_interval = 20
    additional_execute_on = 'FINAL'
  []
  [my_csv]
    type = CSV
    file_base = ./csv_${base_name}
    additional_execute_on = 'FINAL'
  []
  [checkpoint]
    type = Checkpoint
    file_base = ./chk_${base_name}/chk_${base_name}
    time_step_interval = 20
  []
[]
