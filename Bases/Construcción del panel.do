* *****************************************************************
* ARCHIVO: Construcción del panel.do
* AUTOR: Marlon Angulo Ramos
* FECHA: 30/10/2025
* DESCRIPCIÓN: Unión de bases para el análisis
* *****************************************************************
clear all
set more off
cd "C:\Users\Marlon Angulo\Desktop\Maestría Andes\Econometría Avanzada\Trabajo Final\Bases"

* Conversión de txt a dta -------------

/*
local años ///
    20101 20102 20111 20112 20121 20122 ///
    20131 20132 20141 20142 20151 20152 ///
    20161 20162 20171 20172 20181 20182 ///
    20191 20192 20201 20202 20211 20212 ///
    20221 20222 20231 20232 20241 20242

// Convertir cada archivo
foreach año of local años {
    di "Convirtiendo: Examen_Saber_11_`año'.txt"
    
    // Importar desde texto (ajusta delimitador si es necesario)
    import delimited "Examen_Saber_11_`año'.txt", clear varnames(1) encoding(UTF-8)
    
    // Guardar como .dta (esto reduce el tamaño significativamente)
    save "Examen_Saber_11_`año'.dta", replace
    
}

*/


* Revisión de las variables en bases de estudio -------------
/*

local archivos Examen_Saber_11_20102.dta ///
               Examen_Saber_11_20111.dta ///
               Examen_Saber_11_20112.dta ///
               Examen_Saber_11_20121.dta ///
               Examen_Saber_11_20122.dta ///
               Examen_Saber_11_20131.dta ///
               Examen_Saber_11_20132.dta ///
               Examen_Saber_11_20141.dta ///
               Examen_Saber_11_20142.dta ///
               Examen_Saber_11_20151.dta ///
               Examen_Saber_11_20152.dta ///
               Examen_Saber_11_20161.dta ///
               Examen_Saber_11_20162.dta ///
               Examen_Saber_11_20171.dta ///
               Examen_Saber_11_20172.dta ///
               Examen_Saber_11_20181.dta ///
               Examen_Saber_11_20182.dta ///
               Examen_Saber_11_20191.dta ///
               Examen_Saber_11_20192.dta


foreach f of local archivos {
    di "==============================================="
    di "Archivo: `f'"
    di "==============================================="
    describe using "`f'"
    di ""
}

*/


/****************************************************
Construcción de la base panel 2012-2019
****************************************************/


// 1. DEFINIR AÑOS Y VARIABLES CLAVE
local años 20121 20122 20131 20132 20141 20142 20151 20152 20161 20162 20171 20172 20181 20182 20191 20192

// 2. PROCESAR CADA AÑO
foreach año of local años {
    di "Procesando: `año'"
    
    use "Examen_Saber_11_`año'.dta", clear
    
    // CREAR AÑO A PARTIR DE PERIODO
    gen año = int(periodo/10)
    
    // VARIABLES CRÍTICAS - VERIFICAR EXISTENCIA
    capture confirm variable cole_jornada
    if _rc {
        di "ADVERTENCIA: cole_jornada no existe en `año'"
        gen cole_jornada = ""
    }
    
    // ESTANDARIZAR JORNADA (VARIABLE CLAVE PARA TRATAMIENTO)
    gen jornada_std = ""
    replace jornada_std = "COMPLETA" if regexm(upper(cole_jornada), "COMPLETA") | regexm(upper(cole_jornada), "UNICA")
    replace jornada_std = "MAÑANA" if regexm(upper(cole_jornada), "MAÑANA") | regexm(upper(cole_jornada), "MANANA")
    replace jornada_std = "TARDE" if regexm(upper(cole_jornada), "TARDE")
    replace jornada_std = "NOCHE" if regexm(upper(cole_jornada), "NOCHE")
    replace jornada_std = "SABATINA" if regexm(upper(cole_jornada), "SABATINA")
    replace jornada_std = "OTRA" if jornada_std == "" & cole_jornada != ""
    
    // VARIABLES DE RESULTADO - MANEJAR DIFERENTES NOMBRES
    local puntajes = "punt_global punt_matematicas punt_lectura_critica punt_c_naturales punt_ingles punt_sociales_ciudadanas"
    foreach p of local puntajes {
        capture confirm variable `p'
        if _rc {
            gen `p' = .
            di "Creando `p' como missing para `año'"
        }
    }
    
    // MANEJO ESPECIAL PARA PUNTAJES ANTIGUOS
    if `año' <= 20141 {
        // Para años antiguos, usar punt_lenguaje si punt_lectura_critica no existe
        capture confirm variable punt_lenguaje
        if _rc == 0 & punt_lectura_critica[1] == . {
            replace punt_lectura_critica = punt_lenguaje
            di "Usando punt_lenguaje para punt_lectura_critica en `año'"
        }
        
        // Manejar ciencias naturales compuestas
        capture confirm variable punt_biologia punt_quimica punt_fisica
        if _rc == 0 & punt_c_naturales[1] == . {
            egen temp_cnaturales = rowmean(punt_biologia punt_quimica punt_fisica)
            replace punt_c_naturales = temp_cnaturales
            drop temp_cnaturales
            di "Calculando punt_c_naturales como promedio de biologia/quimica/fisica en `año'"
        }
    }
    
    // VARIABLES DE CONTROL SOCIOECONÓMICAS
		// CONVERTIR fami_estratovivienda A NUMÉRICA
capture confirm variable fami_estratovivienda
if _rc == 0 {
    gen estrato_num = .
    replace estrato_num = 1 if strpos(fami_estratovivienda, "Estrato 1")
    replace estrato_num = 2 if strpos(fami_estratovivienda, "Estrato 2")
    replace estrato_num = 3 if strpos(fami_estratovivienda, "Estrato 3")
    replace estrato_num = 4 if strpos(fami_estratovivienda, "Estrato 4")
    replace estrato_num = 5 if strpos(fami_estratovivienda, "Estrato 5")
    replace estrato_num = 6 if strpos(fami_estratovivienda, "Estrato 6")
    // Para "Vive en una zona rural..." asignar missing o valor específico
    replace estrato_num = . if strpos(fami_estratovivienda, "zona rural")
    drop fami_estratovivienda
    rename estrato_num fami_estratovivienda
    di "Convertida fami_estratovivienda a numérica en `año'"
}
else {
    gen fami_estratovivienda = .
}
    local controles = "fami_estratovivienda fami_educacionmadre fami_educacionpadre estu_fechanacimiento estu_genero"
    foreach c of local controles {
        capture confirm variable `c'
        if _rc {
            gen `c' = .
            di "Creando `c' como missing para `año'"
        }
    }

    
    // VARIABLES DEL COLEGIO
    local colegio_vars = "cole_area_ubicacion cole_calendario cole_naturaleza cole_caracter cole_bilingue"
    foreach cv of local colegio_vars {
        capture confirm variable `cv'
        if _rc {
            gen `cv' = ""
            di "Creando `cv' como string vacío para `año'"
        }
    }
    
    // CALCULAR EDAD SI ES POSIBLE
    capture confirm variable estu_fechanacimiento
    if _rc == 0 {
        gen fecha_nac = date(estu_fechanacimiento, "DMY")
        gen edad = (date("01jan"+string(año), "DMY") - fecha_nac)/365.25
        drop fecha_nac
    }
    else {
        gen edad = .
    }
    
    // VARIABLES MODERNAS (A PARTIR DE 2014-2)
// Asegurar que estas variables existan para todos los años
foreach var in estu_inse_individual estu_nse_individual {
    capture confirm variable `var'
    if _rc == 0 {
        // Si existe, convertir a numérico si es string
        capture confirm numeric variable `var'
        if _rc {
            destring `var', replace force
            di "Convertida `var' a numérica en `año'"
        }
    }
    else {
        // Si no existe, crearla como missing
        gen `var' = .
        di "Creando `var' como missing para `año'"
    }
}
    
    // CODIFICAR VARIABLES CATEGÓRICAS PARA AGREGACIÓN
    foreach var in cole_area_ubicacion cole_calendario cole_naturaleza cole_caracter cole_bilingue {
        capture confirm variable `var'
        if _rc == 0 {
            encode `var', gen(`var'_num)
        }
        else {
            gen `var'_num = .
        }
    }
    
    encode jornada_std, gen(jornada_num)
    
    // AGREGAR A NIVEL COLEGIO-AÑO
    collapse (mean) punt_global punt_matematicas punt_lectura_critica punt_c_naturales ///
                     punt_ingles punt_sociales_ciudadanas fami_estratovivienda edad ///
                     estu_inse_individual estu_nse_individual ///
             (firstnm) cole_area_ubicacion_num cole_calendario_num cole_naturaleza_num ///
                     cole_caracter_num cole_bilingue_num jornada_num ///
             (count) n_estudiantes = periodo, ///
             by(cole_cod_dane_establecimiento año)
    
    // ETIQUETAR VARIABLES
    label variable n_estudiantes "Número de estudiantes en el colegio"
    label variable jornada_num "Jornada estandarizada"
    
    // GUARDAR BASE TEMPORAL
    save "temp_`año'.dta", replace
    di "Procesado `año': " _N " observaciones"
}

// 3. CONSOLIDAR TODOS LOS AÑOS
clear
foreach año of local años {
    capture confirm file "temp_`año'.dta"
    if _rc == 0 {
        append using "temp_`año'.dta"
        di "Añadido `año' - Total: " _N
    }
    else {
        di "ERROR: No se encontró temp_`año'.dta"
    }
}

// 4. LIMPIEZA FINAL
// Ordenar datos
sort cole_cod_dane_establecimiento año

// Verificar y eliminar duplicados
duplicates tag cole_cod_dane_establecimiento año, gen(duplicado)
sum duplicado
if r(N) > 0 {
    di "Encontradas " r(N) " observaciones duplicadas. Consolidando..."
    
    // Asegurar que todas las variables necesarias existan
    local numeric_vars = "punt_global punt_matematicas punt_lectura_critica punt_c_naturales punt_ingles punt_sociales_ciudadanas fami_estratovivienda edad estu_inse_individual estu_nse_individual fami_educacionmadre fami_educacionpadre n_estudiantes"
    local categorical_vars = "cole_area_ubicacion_num cole_calendario_num cole_naturaleza_num cole_caracter_num cole_bilingue_num jornada_num"
    
    // Verificar y crear variables numéricas faltantes
    foreach var of local numeric_vars {
        capture confirm variable `var'
        if _rc {
            gen `var' = .
            di "Creando variable faltante: `var'"
        }
    }
    
    // Verificar y crear variables categóricas faltantes  
    foreach var of local categorical_vars {
        capture confirm variable `var'
        if _rc {
            gen `var' = .
            di "Creando variable faltante: `var'"
        }
    }
    
    // Consolidar duplicados
    collapse (mean) `numeric_vars' (firstnm) `categorical_vars', ///
             by(cole_cod_dane_establecimiento año)
}

// Eliminar variable temporal
capture drop duplicado

// Configurar panel
xtset cole_cod_dane_establecimiento año

// 5. GUARDAR BASE FINAL
save "panel_jornada_unica_2012_2019_final.dta", replace

// 6. LIMPIAR ARCHIVOS TEMPORALES
foreach año of local años {
    capture erase "temp_`año'.dta"
}



use panel_jornada_unica_2012_2019_final
// Crear variable de tratamiento (Jornada Única)
gen tratamiento = (jornada_num == 1) if !missing(jornada_num)

label variable tratamiento "Jornada Única"
label define tratamiento 0 "Otra jornada" 1 "Jornada Única"
label values tratamiento tratamiento

tab tratamiento

use panel_jornada_unica_2012_2019_final


keep if cole_naturaleza_num == 2

// Guardar la base final de colegios oficiales
save "panel_jornada_unica_2012_2019_oficiales.dta", replace

