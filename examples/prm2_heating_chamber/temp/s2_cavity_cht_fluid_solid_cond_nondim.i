
# ============================================================
# step3a.i
#
# Step 3a:
# PIMPLE-based transient two-region CHT transition case
#
# Goals
#   - upper block : fluid
#   - lower block : solid
#   - fluid and solid each solve their own temperature variable
#   - interface CHT is enabled
#   - keep PIMPLE framework
#   - turn off buoyancy first (alpha_b = 0) so the case behaves
#     mainly as transient conduction + interface heat transfer
#
# Geometry
#   1x1 square domain:
#     fluid : y in [0.30, 1.00]
#     solid : y in [0.00, 0.30]
#
# Boundary conditions
#   fluid top            : cold temperature
#   fluid left/right     : adiabatic
#   solid bottom         : hot temperature
#   solid left/right     : adiabatic
#   interface            : Robin-Robin CHT
#
# Notes
#   1) This is the recommended "first CHT bridge" after step2.
#   2) We keep velocity/pressure in the PIMPLE solve, but set alpha_b = 0
#      so the flow should remain zero or near zero.
#   3) Once this version is stable, step3b can reopen buoyancy.
# ============================================================

base_name = 'step3_a_v1'

mu = 0.1
rho = 1.0
advected_interp_method = 'average'
cp = 1.0
k = 0.5
alpha_b = 0.0 # 
gravity = '0 0 0' # -9.8
ref_temperature = 0.0

Tbase = 0.05
A = 0.35
sigma = 0.18

# -----------------------------
# Solid properties
# -----------------------------
# rho_s = 1.0
# cp_s = 1.0
k_s = 1.0

[Debug]
  show_mesh_generators = true
[]

[Mesh]
  [box]
    type = CartesianMeshGenerator
    dim = 2

    # x direction: same width, only one column
    dx = '1.0'
    ix = '80'

    # y direction: bottom solid + top fluid
    dy = '0.3 0.7'
    iy = '24 56'

    subdomain_id = '2
                    1'
  []

  [rename_subdomains]
    type = RenameBlockGenerator
    input = box
    old_block = '1 2'
    new_block = 'fluid solid'
  []

  [break_outer_boundaries]
    type = BreakBoundaryOnSubdomainGenerator
    input = rename_subdomains
    boundaries = 'left right top bottom'
  []

  [create_interface]
    type = SideSetsBetweenSubdomainsGenerator
    input = break_outer_boundaries
    primary_block = fluid
    paired_block = solid
    new_boundary = 'interface'
  []
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
    rho = ${rho}
    p_diffusion_kernel = p_diffusion
    block = fluid
  []
[]

[Variables]
  [vel_x]
    type = MooseLinearVariableFVReal
    initial_condition = 0.0
    solver_sys = u_system
    block = fluid
  []
  [vel_y]
    type = MooseLinearVariableFVReal
    solver_sys = v_system
    initial_condition = 0.0
    block = fluid
  []
  [pressure]
    type = MooseLinearVariableFVReal
    solver_sys = pressure_system
    initial_condition = 0.0
    block = fluid
  []
  [T]
    type = MooseLinearVariableFVReal
    solver_sys = energy_system
    initial_condition = 0.0
    block = fluid
  []
  [Ts]
    type = MooseLinearVariableFVReal
    solver_sys = solid_energy_system
    initial_condition = 0.0
    block = solid
  []
[]

[LinearFVKernels]
  # ----------------------------------------------------------
  # Fluid momentum transient terms
  # rho * d(u)/dt
  # rho * d(v)/dt
  # ----------------------------------------------------------
  [u_time]
    type = LinearFVTimeDerivative
    variable = vel_x
    factor = ${rho}
    block = fluid
  []
  [v_time]
    type = LinearFVTimeDerivative
    variable = vel_y
    factor = ${rho}
    block = fluid
  []

  # ----------------------------------------------------------
  # Fluid momentum
  # ----------------------------------------------------------  
  [u_advection_stress]
    type = LinearWCNSFVMomentumFlux
    variable = vel_x
    advected_interp_method = ${advected_interp_method}
    mu = ${mu}
    u = vel_x
    v = vel_y
    momentum_component = 'x'
    rhie_chow_user_object = 'rc'
    use_nonorthogonal_correction = false
    block = fluid 
  []
  [v_advection_stress]
    type = LinearWCNSFVMomentumFlux
    variable = vel_y
    advected_interp_method = ${advected_interp_method}
    mu = ${mu}
    u = vel_x
    v = vel_y
    momentum_component = 'y'
    rhie_chow_user_object = 'rc'
    use_nonorthogonal_correction = false
    block = fluid
  []

  [u_pressure]
    type = LinearFVMomentumPressure
    variable = vel_x
    pressure = pressure
    momentum_component = 'x'
    block = fluid
  []
  [v_pressure]
    type = LinearFVMomentumPressure
    variable = vel_y
    pressure = pressure
    momentum_component = 'y'
    block = fluid
  []

  [u_boussinesq]
    type = LinearFVMomentumBoussinesq
    variable = vel_x
    rho = ${rho}
    gravity = ${gravity}
    alpha_name = ${alpha_b}
    ref_temperature = ${ref_temperature}
    T_fluid = T
    momentum_component = 'x'
    block = fluid
  []
  [v_boussinesq]
    type = LinearFVMomentumBoussinesq
    variable = vel_y
    rho = ${rho}
    gravity = ${gravity}
    alpha_name = ${alpha_b}
    ref_temperature = ${ref_temperature}
    T_fluid = T
    momentum_component = 'y'
    block = fluid
  []

  # ----------------------------------------------------------
  # SIMPLE pressure correction
  # ----------------------------------------------------------
  [p_diffusion]
    type = LinearFVAnisotropicDiffusion
    variable = pressure
    diffusion_tensor = Ainv
    use_nonorthogonal_correction = false
    block = fluid
  []
  [HbyA_divergence]
    type = LinearFVDivergence
    variable = pressure
    face_flux = HbyA
    force_boundary_execution = true
    block = fluid
  []

  # ----------------------------------------------------------
  # Fluid energy transient term
  # rho * cp * dT/dt
  # ----------------------------------------------------------
  [h_time]
    type = LinearFVTimeDerivative
    variable = T
    factor = ${fparse rho*cp}
    block = fluid
  []
  [h_advection]
    type = LinearFVEnergyAdvection
    variable = T
    advected_quantity = temperature
    cp = ${cp}
    advected_interp_method = ${advected_interp_method}
    rhie_chow_user_object = 'rc'
    block = fluid
  []
  [conduction]
    type = LinearFVDiffusion
    variable = T
    diffusion_coeff = ${k}
    use_nonorthogonal_correction = false
    block = fluid
  []

  # ==========================================================
  # Solid energy
  # rho_s * cp_s * dTs/dt = div(k_s grad Ts)
  # ==========================================================
  [solid_h_time]
    type = LinearFVTimeDerivative
    variable = Ts
    block = solid
    factor = 1.0
  []
  [solid_conduction]
    type = LinearFVDiffusion
    variable = Ts
    block = solid
    diffusion_coeff = 1.0
    use_nonorthogonal_correction = false
  []  
[]

[FunctorMaterials]
  [constant_functors]
    type = GenericFunctorMaterial
    prop_names = 'cp alpha_b'
    prop_values = '${cp} ${alpha_b}'
  []
[]

[LinearFVBCs]
  # ----------------------------------------------------------
  # Fluid velocity: no-slip on all external fluid walls and on the interface
  # ----------------------------------------------------------
  [fluid_u_noslip]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_x
    boundary = 'left right top interface'
    functor = 0.0
  []

  [fluid_v_noslip]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_y
    boundary = 'left right top interface'
    functor = 0.0
  []

  # ----------------------------------------------------------
  # Fluid thermal boundary conditions
  # ----------------------------------------------------------
  [fluid_top_temperature]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = T
    boundary = 'top' # 'top_to_fluid'
    functor = 0.0
  []

  [fluid_side_adiabatic]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    variable = T
    boundary = 'left right'
    functor = 0.0
  []

  # ==========================================================
  # Solid thermal BCs
  # ==========================================================
  [solid_bottom_temperature]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = Ts
    boundary = 'bottom' # 'bottom_to_solid'
    functor = bottom_T_profile
  []

  [solid_side_adiabatic]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    variable = Ts
    boundary = 'left right'
    functor = 0.0
  []

  # ----------------------------------------------------------
  # Fluid-solid interface (Robin-Robin CHT)
  # ----------------------------------------------------------
  [cht_fluid_side]
    type = LinearFVRobinCHTBC
    variable = T
    boundary = interface
    h = 1
    incoming_flux = heat_flux_to_fluid_interface
    surface_temperature = interface_temperature_solid_interface
    thermal_conductivity = ${k}
  []

  [cht_solid_side]
    type = LinearFVRobinCHTBC
    variable = Ts
    boundary = interface
    h = 1
    incoming_flux = heat_flux_to_solid_interface
    surface_temperature = interface_temperature_fluid_interface
    thermal_conductivity = ${k_s}
  []  
[]

[Functions]
  [bottom_T_profile]
    type = ParsedFunction
    expression = '${Tbase} + ${A}*exp(-((x-0.5)^2)/(2*${sigma}^2))'
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
    block = fluid
    functor = T
  []

  [T_in_solid]
    type = FunctorAux
    variable = T_total
    block = solid
    functor = Ts
  []
[]

[Executioner]
  type = PIMPLE

  should_solve_energy = true
  should_solve_momentum = true
  should_solve_pressure = true
  should_solve_solid_energy = true

  momentum_l_abs_tol = 1e-8
  pressure_l_abs_tol = 1e-8
  energy_l_abs_tol = 1e-8
  solid_energy_l_abs_tol = 1e-8

  momentum_l_tol = 0
  pressure_l_tol = 0
  energy_l_tol = 0

  rhie_chow_user_object = 'rc'
  momentum_systems = 'u_system v_system'
  pressure_system = 'pressure_system'
  energy_system = 'energy_system'
  solid_energy_system = 'solid_energy_system'

  momentum_equation_relaxation = 0.5
  pressure_variable_relaxation = 0.2
  energy_equation_relaxation = 0.8

  num_iterations = 20

  pressure_absolute_tolerance = 1e-6
  momentum_absolute_tolerance = 1e-6
  energy_absolute_tolerance = 1e-6
  solid_energy_absolute_tolerance = 1e-4

  pin_pressure = true 
  pressure_pin_point = '0.5 0.8 0'
  pressure_pin_value = 0

  # CHT controls
  cht_interfaces = 'interface'
  cht_solid_flux_relaxation = 0.7
  cht_fluid_flux_relaxation = 0.7
  cht_solid_temperature_relaxation = 0.7
  cht_fluid_temperature_relaxation = 0.7
  cht_heat_flux_tolerance = 1.0e-4
  max_cht_fpi = 3

  print_fields = false
  continue_on_max_its = false

  # end_time = 1.0
  num_steps = 100
  num_piso_iterations = 0

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 1.0e-5
    optimal_iterations = 4
    iteration_window = 2
    growth_factor = 1.2
    cutback_factor = 0.5
  []
[]

[Postprocessors]
  [./dt]
    type = TimestepSize
  [../]
  [./run_time]
    type = PerfGraphData
    section_name = "Root"
    data_type = total
  [../]
[]

[Outputs]
  [./my_exodus]
    file_base = ./ex_${base_name}/out_${base_name}
    type = Exodus
    time_step_interval = 2
    additional_execute_on = 'FINAL'
  [../]
  csv = true
[]
