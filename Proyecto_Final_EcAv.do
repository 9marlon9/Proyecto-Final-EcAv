* *****************************************************************
* ARCHIVO: Proyecto_Final_EcAv.do
* AUTOR: Marlon Angulo Ramos
* FECHA: 05/12/2025
* DESCRIPCIÓN: Metodología 
* *****************************************************************
clear all
ssc install distinct


* *****************************************************************
* 1. Sección de datos
* *****************************************************************
* Descargar la base directamente desde GitHub
copy "https://github.com/9marlon9/Proyecto-Final-EcAv/raw/master/Bases/panel_jornada_unica_2012_2019_oficiales.dta" "panel_jornada_unica_2012_2019_oficiales.dta", replace

* Abrir la base
use "panel_jornada_unica_2012_2019_oficiales.dta", clear

*Generar variable de tratamiento
drop if tratamiento == .
gen tratado = (tratamiento == 1)
label variable tratado "Indicador: 1 si el colegio está en Jornada Única"

*Variable de adopción Gi
bys cole_cod_dane_establecimiento: egen Gi = min(cond(tratado == 1, año, .))
label variable Gi "Año de adopción de la Jornada Única"


* Observaciones totales
count

*Colrgios en jornada única
tab tratamiento

* Colegios únicos
distinct cole_cod_dane_establecimiento

* Años disponibles
tab año

* Estadísticas descriptivas: 

summarize punt_global punt_matematicas punt_lectura_critica ///
          punt_c_naturales punt_ingles punt_sociales_ciudadanas ///
          fami_estratovivienda estu_inse_individual estu_nse_individual ///
          edad n_estudiantes
	  
preserve
collapse (mean) punt_global, by(año)
list, clean
restore


preserve
keep if año < 2015

tabstat punt_global fami_estratovivienda estu_inse_individual ///
        estu_nse_individual n_estudiantes, ///
        by(tratado) statistics(mean sd n)

restore

tab Gi

bys cole_cod_dane_establecimiento: egen ever_treated = max(tratado)
tab ever_treated

preserve
keep cole_cod_dane_establecimiento Gi
duplicates drop
tab Gi
restore

ds


* *****************************************************************
* 2. Metodología
* *****************************************************************


*--------------------------------------------------------------*
* 1. Variable de tratamiento (tratado) y cohortes de adopción
*--------------------------------------------------------------*

label var tratado "Indicador: 1 si el colegio está en Jornada Única"

* Ever treated (colegios que alguna vez adoptan jornada única)
label var ever_treated "1 si el colegio adopta Jornada Única en algún año"

* Cohorte de adopción Gi = primer año en que el colegio es tratado
label var Gi "Año de adopción de la Jornada Única (cohorte)"

*--------------------------------------------------------------*
* 2. Variable gvar para csdid (0 = never treated, año de adopción para tratados)
*--------------------------------------------------------------*

gen gvar = Gi
replace gvar = 0 if ever_treated == 0
label var gvar "Cohorte de adopción (0 = nunca tratado)"

tab gvar


*--------------------------------------------------------------*
* 3. Instalar paquetes (solo la primera vez)
*--------------------------------------------------------------*
ssc install drdid, replace
ssc install csdid, replace

*--------------------------------------------------------------*
* 4. Estimación DID Callaway & Sant'Anna sobre puntaje global
*    (Outcome principal: punt_global)
*--------------------------------------------------------------*

* Nota: csdid automáticamente ignora observaciones con punt_global missing.
* los ATT(g,t) se estiman solo para años donde hay información.

csdid punt_global, ///
    ivar(cole_cod_dane_establecimiento) ///
    time(año) ///
    gvar(gvar) ///
    method(dripw)


*--------------------------------------------------------------*
* 5. Resúmenes de efectos causales
*--------------------------------------------------------------*

* 5.1. Efecto promedio del tratamiento (ATT simple sobre todos los g,t)
estat simple
* 5.2. Efectos promedio por cohorte de adopción (ATT por G)
estat group
* 5.3. Efectos por año calendario (ATT por t)
estat calendar
* 5.4. Event study (efectos por distancia a tratamiento t - g)
estat event
* Si quieres limitar la ventana de eventos (por ejemplo, -3 a +4 años):
estat event, window(-3 4)
*--------------------------------------------------------------*
* 6. Gráfico del Event Study
*--------------------------------------------------------------*

csdid_plot, title("Efectos dinámicos de la Jornada Única sobre puntaje global") ///
    name(fig_event_pg, replace)

	
*--------------------------------------------------------------*
* 7. CSDID con covariables (ajustando por composición)
*--------------------------------------------------------------*

csdid punt_global ///
    fami_estratovivienda estu_inse_individual n_estudiantes, ///
    ivar(cole_cod_dane_establecimiento) ///
    time(año) ///
    gvar(gvar) ///
    method(dripw)

* Luego repetir la post-estimación:
estat simple
estat group
estat event, window(-3 4)

csdid_plot, title("Event study ajustado por covariables") ///
    name(fig_event_pg_cov, replace)

	
	
*--------------------------------------------------------------*
* 8. Excluir cohortes tempranas)
*--------------------------------------------------------------*
	
	
use panel_jornada_unica_2012_2019_oficiales, clear

drop if tratamiento == .
gen tratado = (tratamiento == 1)

bys cole_cod_dane_establecimiento: egen Gi = min(cond(tratado == 1, año, .))
bys cole_cod_dane_establecimiento: egen ever_treated = max(tratado)

* Definir nueva cohorte solo para adopciones a partir de 2015
gen gvar_late = .
replace gvar_late = 0 if ever_treated == 0
replace gvar_late = Gi if Gi >= 2015 & Gi <= 2019

label var gvar_late "Cohorte adopción (>=2015; 0 = nunca tratado)"

* Mantener solo never-treated y adoptantes 2015-2019
keep if gvar_late == 0 | inrange(gvar_late, 2015, 2019)

csdid punt_global ///
    fami_estratovivienda estu_inse_individual n_estudiantes, ///
    ivar(cole_cod_dane_establecimiento) ///
    time(año) ///
    gvar(gvar_late) ///
    method(dripw)

estat simple
estat group
estat event, window(-3 4)

	
	
	
* *****************************************************************
* 2.1 Evaluación de supuestos
* *****************************************************************

use panel_jornada_unica_2012_2019_oficiales, clear

* 1. Crear indicador de tratado anual
drop if tratamiento == .
gen tratado = (tratamiento == 1)

* 2. Ever treated y año de adopción Gi
bys cole_cod_dane_establecimiento: egen ever_treated = max(tratado)
bys cole_cod_dane_establecimiento: egen Gi = min(cond(tratado == 1, año, .))

* 3. Cohorte "tarde": solo adopciones 2015–2019
gen gvar_late = .
replace gvar_late = 0 if ever_treated == 0
replace gvar_late = Gi if inrange(Gi, 2015, 2019)

label var gvar_late "Cohorte adopción (>=2015; 0 = nunca tratado)"

* 4. Mantener solo never-treated y adoptantes 2015–2019
keep if gvar_late == 0 | inrange(gvar_late, 2015, 2019)

* 5. Panel
xtset cole_cod_dane_establecimiento año



* Tendencias paralelas
use panel_jornada_unica_2012_2019_oficiales, clear

* 1. Definir tratado y Gi
drop if tratamiento == .
gen tratado = (tratamiento == 1)

bys cole_cod_dane_establecimiento: egen ever_treated = max(tratado)
bys cole_cod_dane_establecimiento: egen Gi = min(cond(tratado == 1, año, .))

* 2. Cohorte de adopción "tarde": 2015–2019
gen gvar_late = .
replace gvar_late = 0 if ever_treated == 0
replace gvar_late = Gi if inrange(Gi, 2015, 2019)

label var gvar_late "Cohorte adopción (>=2015; 0 = nunca tratado)"

* 3. Mantener solo never-treated y adoptantes 2015–2019
keep if gvar_late == 0 | inrange(gvar_late, 2015, 2019)

* 4. Grupo: 0 = nunca tratados, 1 = futuros tratados
gen grupo_futuro = (gvar_late >= 2015)
label define grupo_futuro 0 "Nunca tratados" 1 "Futuros tratados"
label values grupo_futuro grupo_futuro

* 5. Gráfico de medias por año (solo donde punt_global no es missing)
preserve

keep if !missing(punt_global)   

collapse (mean) punt_global, by(año grupo_futuro)

twoway ///
    (line punt_global año if grupo_futuro==0, lpattern(solid)  lwidth(medthick)) ///
    (line punt_global año if grupo_futuro==1, lpattern(dash)   lwidth(medthick)), ///
    legend(order(1 "Nunca tratados" 2 "Futuros tratados")) ///
    ytitle("Puntaje global medio") ///
    xtitle("Año") ///
    xline(2015, lpattern(shortdash) lcolor(gs8)) ///
    title("Tendencias del puntaje global por grupo") ///
    name(fig_trends_global, replace)

restore



* CSDID con covariables (como en el paper)
csdid punt_global ///
    fami_estratovivienda estu_inse_individual n_estudiantes, ///
    ivar(cole_cod_dane_establecimiento) ///
    time(año) ///
    gvar(gvar_late) ///
    method(dripw)

* Event study completo
estat event, window(-3 4)

* No anticipación

use panel_jornada_unica_2012_2019_oficiales, clear

drop if tratamiento == .
gen tratado = (tratamiento == 1)
bys cole_cod_dane_establecimiento: egen ever_treated = max(tratado)
bys cole_cod_dane_establecimiento: egen Gi = min(cond(tratado == 1, año, .))

* Placebo: adelantar un año la adopción (como si la política empezara antes)
gen Gi_placebo = Gi - 1

* Cohorte placebo solo para adopciones reales 2015–2019
gen gvar_placebo = .
replace gvar_placebo = 0 if ever_treated == 0
replace gvar_placebo = Gi_placebo if inrange(Gi, 2015, 2019)

* Mantener solo never-treated y adoptantes 2015–2019
keep if gvar_placebo == 0 | inrange(gvar_placebo, 2014, 2018)

xtset cole_cod_dane_establecimiento año

* Estimar CSDID placebo
csdid punt_global ///
    fami_estratovivienda estu_inse_individual n_estudiantes, ///
    ivar(cole_cod_dane_establecimiento) ///
    time(año) ///
    gvar(gvar_placebo) ///
    method(dripw)

estat event, window(-3 4)


* Soporte común

use panel_jornada_unica_2012_2019_oficiales, clear

drop if tratamiento == .
gen tratado = (tratamiento == 1)
bys cole_cod_dane_establecimiento: egen ever_treated = max(tratado)
bys cole_cod_dane_establecimiento: egen Gi = min(cond(tratado == 1, año, .))

* Misma gvar_late que usamos en la estimación principal
gen gvar_late = .
replace gvar_late = 0 if ever_treated == 0
replace gvar_late = Gi if inrange(Gi, 2015, 2019)
keep if gvar_late == 0 | inrange(gvar_late, 2015, 2019)

* Definir dummy de "ever treated late"
gen treated_late = (gvar_late >= 2015)
label var treated_late "Alguna vez adopta Jornada Única (2015-2019)"

* Modelo logit del tratamiento (a nivel colegio, usando primer año observado)
bys cole_cod_dane_establecimiento: egen first_year = min(año)
keep if año == first_year

logit treated_late ///
    fami_estratovivienda estu_inse_individual n_estudiantes

predict pscore, pr
label var pscore "Probabilidad estimada de adopción (PS)"

* Histograma del propensity score por grupo
twoway ///
    (histogram pscore if treated_late==0, width(0.02) color(gs12) ///
         lcolor(black) lwidth(thin) ) ///
    (histogram pscore if treated_late==1, width(0.02) color(none) ///
         lcolor(black) lpattern(dash)), ///
    legend(order(1 "Nunca tratados" 2 "Futuros tratados") ///
           ring(0) pos(11)) ///
    xtitle("Propensity score") ///
    ytitle("Densidad") ///
    title("Soporte común en la probabilidad de adopción") ///
    name(fig_pscore_overlap, replace)

* Balance de covariables pre tratamiento

use panel_jornada_unica_2012_2019_oficiales, clear

drop if tratamiento == .
gen tratado = (tratamiento == 1)
bys cole_cod_dane_establecimiento: egen ever_treated = max(tratado)
bys cole_cod_dane_establecimiento: egen Gi = min(cond(tratado == 1, año, .))

gen gvar_late = .
replace gvar_late = 0 if ever_treated == 0
replace gvar_late = Gi if inrange(Gi, 2015, 2019)
keep if gvar_late == 0 | inrange(gvar_late, 2015, 2019)

* Definir grupo
gen grupo_futuro = (gvar_late >= 2015)
label define grupo_futuro 0 "Nunca tratados" 1 "Futuros tratados"
label values grupo_futuro grupo_futuro

* Solo años pretratamiento (2012-2014)
keep if año < 2015

* Tablas de balance (medias y desvíos estándar)
tabstat fami_estratovivienda estu_inse_individual n_estudiantes ///
        punt_global, ///
        by(grupo_futuro) statistics(mean sd n)

