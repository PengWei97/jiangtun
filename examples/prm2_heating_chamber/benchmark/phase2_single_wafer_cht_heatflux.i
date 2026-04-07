# ==========================================================
# phase2_single_wafer_cht_heatflux.i
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

base_name = 'phase2_single_wafer_cht_heatflux'

# -----------------------------
# nondimensional groups
# -----------------------------
Re = 50
Pr = 0.7
mu_fluid = ${fparse 1.0/Re}
alpha_fluid = ${fparse 1.0/(Re*Pr)}

# solid/fluid thermal-property ratios
k_solid = 0.2
rhoCp_fluid = 1.0
rhoCp_solid = 5.0
solid_cap_ratio = ${fparse rhoCp_solid / rhoCp_fluid}

# numerical controls
advected_interp_method = 'average'
cht_h_scale = 1.0


# -----------------------------
# wall heating controls
# -----------------------------
# Positive values correspond to positive n·(alpha grad T), which injects
# heat into the domain for both the top and bottom horizontal walls.
wall_heat_flux_top = 0.10
wall_heat_flux_bottom = 0.10

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

[Mesh]
  [box]
    type = CartesianMeshGenerator
    dim = 2

    # x direction:
    # left far field / pre-wafer refined / wafer / post-wafer refined / right far field
    dx = '2.20 0.295 0.01 0.295 2.20'
    ix = '70 40 10 40 70'

    # y direction:
    # lower fluid / wafer span / upper fluid
    dy = '0.25 1.0 0.25'
    iy = '12 50 12'

    # 3 x 5 block layout:
    #   1 1 1 1 1
    #   1 1 2 1 1
    #   1 1 1 1 1
    subdomain_id = '1 1 1 1 1
                    1 1 2 1 1
                    1 1 1 1 1'
  []

  [interface]
    type = SideSetsBetweenSubdomainsGenerator
    input = box
    primary_block = '1'
    paired_block = '2'
    new_boundary = 'interface'
  []

  parallel_type = distributed
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
    block = 2
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
  [solid_h_time]
    type = LinearFVTimeDerivative
    variable = T_solid
    factor = ${solid_cap_ratio}
  []
  [solid_conduction]
    type = LinearFVDiffusion
    variable = T_solid
    diffusion_coeff = ${k_solid}
    use_nonorthogonal_correction = false
  []
[]

[LinearFVBCs]
  # -----------------------------
  # inlet
  # -----------------------------
  [inlet_u]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_x
    boundary = left
    functor = 1.0
  []
  [inlet_v]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_y
    boundary = left
    functor = 0.0
  []
  [inlet_T]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = T_fluid
    boundary = left
    functor = 0.0
  []

  # -----------------------------
  # outer walls + wafer no-slip
  # -----------------------------
  [walls_u]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_x
    boundary = 'top bottom interface'
    functor = 0.0
  []
  [walls_v]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_y
    boundary = 'top bottom interface'
    functor = 0.0
  []

  [top_wall_heat_flux]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    variable = T_fluid
    boundary = top
    functor = ${wall_heat_flux_top}
    diffusion_coeff = ${alpha_fluid}
  []
  [bottom_wall_heat_flux]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    variable = T_fluid
    boundary = bottom
    functor = ${wall_heat_flux_bottom}
    diffusion_coeff = ${alpha_fluid}
  []

  # -----------------------------
  # outlet
  # -----------------------------
  [outlet_p]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = pressure
    boundary = right
    functor = 0.0
  []
  [outlet_u]
    type = LinearFVAdvectionDiffusionOutflowBC
    variable = vel_x
    boundary = right
  []
  [outlet_v]
    type = LinearFVAdvectionDiffusionOutflowBC
    variable = vel_y
    boundary = right
  []
  [outlet_T]
    type = LinearFVAdvectionDiffusionOutflowBC
    variable = T_fluid
    boundary = right
  []

  # -----------------------------
  # fluid-solid CHT interface
  # -----------------------------
  [fluid_solid]
    type = LinearFVRobinCHTBC
    variable = T_fluid
    boundary = interface
    h = ${cht_h_scale}
    incoming_flux = heat_flux_to_fluid_interface
    surface_temperature = interface_temperature_solid_interface
    thermal_conductivity = ${alpha_fluid}
  []
  [solid_fluid]
    type = LinearFVRobinCHTBC
    variable = T_solid
    boundary = interface
    h = ${cht_h_scale}
    incoming_flux = heat_flux_to_solid_interface
    surface_temperature = interface_temperature_fluid_interface
    thermal_conductivity = ${k_solid}
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
    block = 2
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
  cht_interfaces = 'interface'
  cht_solid_flux_relaxation = 0.4
  cht_fluid_flux_relaxation = 0.4
  cht_solid_temperature_relaxation = 0.5
  cht_fluid_temperature_relaxation = 0.5
  max_cht_fpi = 20

  print_fields = false
  continue_on_max_its = true

  end_time = 5
  # num_steps = 60
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
  # ----------------------------------------------------------
  # Quantities that are easy to compare across Phase 0/1/2/... 
  # and are cumbersome to export directly as time histories from
  # ParaView/Exodus alone.
  # ----------------------------------------------------------

  # --- time stepping / solver performance ---
  [dt]
    type = TimestepSize
  []
  [run_time]
    type = PerfGraphData
    section_name = 'Root'
    data_type = total
  []

  # --- wafer temperature metrics (best kept directly in CSV) ---
  [wafer_T_avg]
    type = ElementAverageValue
    variable = T_solid
    block = 2
  []
  [wafer_T_max]
    type = ElementExtremeValue
    variable = T_solid
    block = 2
    value_type = max
  []
  [wafer_T_min]
    type = ElementExtremeValue
    variable = T_solid
    block = 2
    value_type = min
  []
  [wafer_delta_T]
    type = ParsedPostprocessor
    pp_names = 'wafer_T_max wafer_T_min'
    pp_symbols = 'tmax tmin'
    expression = 'tmax - tmin'
  []

  # --- fluid / global thermal state ---
  [fluid_T_avg]
    type = ElementAverageValue
    variable = T_fluid
    block = 1
  []
  [domain_T_avg]
    type = ElementAverageValue
    variable = T_total
  []

  # --- outlet bulk temperature and pressure diagnostics ---
  [outlet_T_avg]
    type = SideAverageValue
    variable = T_fluid
    boundary = right
  []
  [outlet_p_avg]
    type = SideAverageValue
    variable = pressure
    boundary = right
  []
  [inlet_p_avg]
    type = SideAverageValue
    variable = pressure
    boundary = left
  []
  [delta_p_inlet_minus_outlet]
    type = DifferencePostprocessor
    value1 = inlet_p_avg
    value2 = outlet_p_avg
  []

  # --- wall heating diagnostics ---
  [top_wall_T_avg]
    type = SideAverageValue
    variable = T_fluid
    boundary = top
  []
  [bottom_wall_T_avg]
    type = SideAverageValue
    variable = T_fluid
    boundary = bottom
  []
  [top_wall_heat_in_avg]
    type = SideDiffusiveFluxAverage
    variable = T_fluid
    boundary = top
    functor_diffusivity = ${alpha_fluid}
  []
  [bottom_wall_heat_in_avg]
    type = SideDiffusiveFluxAverage
    variable = T_fluid
    boundary = bottom
    functor_diffusivity = ${alpha_fluid}
  []
  [top_wall_heat_in_integral]
    type = SideDiffusiveFluxIntegral
    variable = T_fluid
    boundary = top
    functor_diffusivity = ${alpha_fluid}
  []
  [bottom_wall_heat_in_integral]
    type = SideDiffusiveFluxIntegral
    variable = T_fluid
    boundary = bottom
    functor_diffusivity = ${alpha_fluid}
  []
  [wall_heat_in_integral_total]
    type = LinearCombinationPostprocessor
    pp_names = 'top_wall_heat_in_integral bottom_wall_heat_in_integral'
    pp_coefs = '1 1'
    b = 0
  []

  # --- simple flow indicators ---
  [u_fluid_avg]
    type = ElementAverageValue
    variable = vel_x
    block = 1
  []
  [v_fluid_avg]
    type = ElementAverageValue
    variable = vel_y
    block = 1
  []
  [u_fluid_max_abs]
    type = ElementExtremeValue
    variable = vel_x
    block = 1
    value_type = max_abs
  []
  [v_fluid_max_abs]
    type = ElementExtremeValue
    variable = vel_y
    block = 1
    value_type = max_abs
  []

  # --- interface diagnostics that are not easy to reconstruct from Exodus ---
  [interface_area]
    type = AreaPostprocessor
    boundary = interface
  []
  [q_interface_to_fluid_integral]
    type = SideIntegralFunctorPostprocessor
    boundary = interface
    functor = heat_flux_to_fluid_interface
    functor_argument = face
  []
  [q_interface_to_solid_integral]
    type = SideIntegralFunctorPostprocessor
    boundary = interface
    functor = heat_flux_to_solid_interface
    functor_argument = face
  []
  [q_interface_to_fluid_avg]
    type = ParsedPostprocessor
    pp_names = 'q_interface_to_fluid_integral interface_area'
    pp_symbols = 'qf Aint'
    expression = 'qf / Aint'
  []
  [q_interface_to_solid_avg]
    type = ParsedPostprocessor
    pp_names = 'q_interface_to_solid_integral interface_area'
    pp_symbols = 'qs Aint'
    expression = 'qs / Aint'
  []
  [minus_q_interface_to_solid_integral]
    type = LinearCombinationPostprocessor
    pp_names = 'q_interface_to_solid_integral'
    pp_coefs = '-1'
    b = 0
  []
  [interface_flux_rel_mismatch]
    type = RelativeDifferencePostprocessor
    value1 = q_interface_to_fluid_integral
    value2 = minus_q_interface_to_solid_integral
  []
  [interface_temperature_fluid_avg]
    type = SideIntegralFunctorPostprocessor
    boundary = interface
    functor = interface_temperature_fluid_interface
    functor_argument = face
  []
  [interface_temperature_solid_avg]
    type = SideIntegralFunctorPostprocessor
    boundary = interface
    functor = interface_temperature_solid_interface
    functor_argument = face
  []
  [interface_T_fluid_area_avg]
    type = ParsedPostprocessor
    pp_names = 'interface_temperature_fluid_avg interface_area'
    pp_symbols = 'Tfint Aint'
    expression = 'Tfint / Aint'
  []
  [interface_T_solid_area_avg]
    type = ParsedPostprocessor
    pp_names = 'interface_temperature_solid_avg interface_area'
    pp_symbols = 'Tsint Aint'
    expression = 'Tsint / Aint'
  []
[]

[Outputs]
  [my_exodus]
    type = Nemesis
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
