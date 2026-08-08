import math
z = 1.96 + 0.84  # 5% two-sided, 80% power

def mde_continuous(N, T, sd_eps, sd_D, rho):
    # effective independent periods under AR-like serial corr (Moulton/design effect)
    Teff = T / (1 + (T - 1) * rho)
    return z * sd_eps / (sd_D * math.sqrt(N * Teff))

def mde_binary_did(N, T, share_treated, sd_eps, rho):
    Teff = T / (1 + (T - 1) * rho)
    var_D = share_treated * (1 - share_treated)   # approx post-x-treat variance share
    # DiD interaction: effective variance ~ p(1-p)*q(1-q) with q = post share = 0.5
    var_D = var_D * 0.25
    return z * sd_eps / (math.sqrt(var_D) * math.sqrt(N * Teff))

print("=== Panel distrital (administrativo), outcome = tasa de informalidad (0-1) ===")
for N,label in [(1874,"todos los distritos"),(600,"distritos con potencial aurifero + controles"),(200,"solo auriferos")]:
    for rho in [0.5,0.8]:
        m = mde_binary_did(N, 20, 0.15, 0.05, rho)
        print(f"N={N:5d} ({label:42s}) rho={rho}  MDE(DiD binario) = {m*100:.2f} pp")
print()
print("=== Bartik continuo: beta sobre (exposicion_i x log precio_t), exposicion estandarizada ===")
for N in [1874, 600]:
    for rho in [0.5, 0.8]:
        # sd_D = sd of (g_i standardized x log p_t demeaned); sd(log p) over 2004-2023 ~ 0.35
        for sdlp in [0.35]:
            m = mde_continuous(N, 20, 0.05, 1.0*sdlp, rho)
            print(f"N={N:5d} rho={rho} sd(log p)={sdlp}  MDE = {m*100:.2f} pp por 1sd exposicion x 1 log-unidad precio")
            print(f"        -> efecto de un alza de 50% del precio (dlogp=0.405): {m*0.405*100:.2f} pp")
print()
print("=== ENAHO agregada a nivel provincial (196 provincias) ===")
for N in [196, 25]:
    for rho in [0.5]:
        for sd_eps in [0.03, 0.05]:
            m = mde_continuous(N, 20, sd_eps, 0.35, rho)
            print(f"N={N:4d} sd_eps={sd_eps} rho={rho}  MDE = {m*100:.2f} pp (por log-unidad precio x 1sd exp.)")
