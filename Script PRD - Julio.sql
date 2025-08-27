--Creacion de tabla para registrar constancias de comunicaciones
CREATE TABLE CONTANCIAS_LOG_COMUNICACIONES(
    ID NUMBER GENERATED ALWAYS AS IDENTITY START WITH 1 INCREMENT BY 1,
    PRIMARY KEY(ID),
    TIPO_CONSTANCIA VARCHAR2(200),
    CLIENTE VARCHAR2(200),
    FECHA_SOLICITUD TIMESTAMP,
    USUARIO_SOLICITANTE VARCHAR2(200),
    FILENAME VARCHAR2(200),
    FILECONTENT BLOB,
    MIMETYPE VARCHAR2(200)
    

);
--Trigger para generar código de constancia automáticamente
create or replace TRIGGER TRG_LOG_CONSTANCIAS_GUID
BEFORE INSERT ON CONTANCIAS_LOG_COMUNICACIONES
FOR EACH ROW
DECLARE
  v_num NUMBER;
BEGIN

  IF :NEW.TIPO_CONSTANCIA = 'De Proceso' THEN 

  SELECT NVL(MAX(TO_NUMBER(CODIGO_CONSTANCIA)), 0) + 1 INTO v_num 
  FROM CONTANCIAS_LOG_COMUNICACIONES WHERE TIPO_CONSTANCIA = 'De Proceso' AND CLIENTE = :NEW.CLIENTE ;

  :NEW.CODIGO_CONSTANCIA := LPAD(v_num, 4, '0');

  ELSE 

  SELECT NVL(MAX(TO_NUMBER(CODIGO_CONSTANCIA)), 0) + 1 INTO v_num 
  FROM CONTANCIAS_LOG_COMUNICACIONES WHERE TIPO_CONSTANCIA = 'De Certificados' AND CLIENTE = :NEW.CLIENTE;

  :NEW.CODIGO_CONSTANCIA := LPAD(v_num, 4, '0');
END IF;
  

END;

--Creacion de documento para plantilla constancia de proceso
create or replace FUNCTION CONSTANCIA_PROCESO_COMUNICACIONES (p_proceso_id NUMBER,p_razon_social VARCHAR2) RETURN CLOB IS 
  l_return clob;
  l_valor_filtrado VARCHAR2(4000);
begin
  l_valor_filtrado := '''' || REPLACE(p_razon_social, '''', '''''') || '''';
  l_return := q'!
      SELECT 
  'contacto_info' AS "filename",
  CURSOR(
    SELECT 
      CURSOR(
            SELECT 
               p.id AS proceso_id,
               gc.RAZON_SOCIAL AS RAZON_SOCIAL,
               TO_CHAR(SYSDATE, 'DD "de" FMmonth "del" YYYY', 'NLS_DATE_LANGUAGE=SPANISH') AS FECHA_ACTUAL,
               biep.estado,
               btp.tipo_proceso AS TIPO_AUDITORIA,
               gc.id_fiscal_ppm AS NIT,
               TO_CHAR(gnp.fecha_final,'DD/MM/YYYY') AS FECHA_EJECUCCION_SERVICIO
               
             FROM BPM_PROCESOS p 
             JOIN GES_CLIENTES gc ON gc.id = p.cliente_id
             JOIN GES_NORMAS_PROCESOS gnp ON gnp.proceso_id = p.id
             JOIN BPM_IMG_ESTADOS_PROCESOS biep ON biep.id = p.estado_id
             JOIN BPM_TIPOS_PROCESOS btp ON btp.id = p.tipo_id
             
             WHERE p.id = #PROCESO_ID# FETCH FIRST 1 ROW ONLY

      
      ) AS "CONSTANCIA_PROCESO",
      CURSOR(
        SELECT 
               p.id AS proceso_id,
               gc.RAZON_SOCIAL AS RAZON_SOCIAL,
               TO_CHAR(SYSDATE, 'DD "de" MONTH "del" YYYY', 'NLS_DATE_LANGUAGE=SPANISH') AS FECHA_ACTUAL,
               biep.estado,
               btp.tipo_proceso AS TIPO_AUDITORIA,
               gc.id_fiscal_ppm AS NIT,
               gnp.alcance AS ALCANCE,
               gnt.nombre AS NORMA,
               TO_CHAR(gce.FECHA_OTORGAMIENTO,'DD/MM/YYYY') AS FECHA_OTORGAMIENTO,
               TO_CHAR(gce.FECHA_VENCIMIENTO,'DD/MM/YYYY') AS FECHA_VENCIMIENTO,
               gce.numero_certificado AS NUMERO_CERTIFICADO,
               gce.direccion_cliente AS DIRECCION_O,
               TO_CHAR(gnp.fecha_final,'DD/MM/YYYY') AS FECHA_EJECUCCION_SERVICIO
             FROM BPM_PROCESOS p 
             JOIN GES_CLIENTES gc ON gc.id = p.cliente_id
             JOIN BPM_IMG_ESTADOS_PROCESOS biep ON biep.id = p.estado_id
             JOIN BPM_TIPOS_PROCESOS btp ON btp.id = p.tipo_id
             JOIN GES_NORMAS_PROCESOS gnp ON gnp.proceso_id = p.id
             JOIN GES_NORMAS_TECNICAS gnt ON gnt.id = gnp.norma_id
             JOIN GES_CERTIFICADOS gce ON gce.id = gnp.certificado_id
             WHERE  btp.tipo_proceso = 'Otorgamiento'  AND p.id = #PROCESO_ID#
      ) AS "OTORGAMIENTO", 
      CURSOR (
             SELECT 
               gce.ALCANCE_ESPANOL AS ALCANCE_CERTIFICACION,
               gce.DIRECCION_CLIENTE AS DIRECCION,
               gnt.nombre AS NORMA,
               TO_CHAR(gce.FECHA_OTORGAMIENTO,'DD/MM/YYYY') AS FECHA_OTORGAMIENTO,
               TO_CHAR(gce.FECHA_VENCIMIENTO,'DD/MM/YYYY') AS FECHA_VENCIMIENTO,
               gce.numero_certificado AS NUMERO_CERTIFICADO
               
             FROM BPM_PROCESOS p 
             JOIN GES_CLIENTES gc ON gc.id = p.cliente_id
             JOIN BPM_IMG_ESTADOS_PROCESOS biep ON biep.id = p.estado_id
             JOIN BPM_TIPOS_PROCESOS btp ON btp.id = p.tipo_id
             JOIN GES_NORMAS_PROCESOS gnp ON gnp.proceso_id = p.id
             JOIN GES_NORMAS_TECNICAS gnt ON gnt.id = gnp.norma_id
             JOIN GES_CERTIFICADOS gce ON gce.id = gnp.certificado_id
             WHERE btp.tipo_proceso NOT IN ('Adjunto Otorgamiento/Renovación','Transferencia','Preaditoria','Adjunto otorgamiento','Adjunto Ampliación/Reducción','Adjunto renovación','Adjunto reactivación','OT vencimiento','Basura Cero','Extraordinaria')
                      

             AND p.id = #PROCESO_ID#
      ) AS "OTROS_PROCESOS",
      CURSOR(
               SELECT 
               biep.estado as estado
               
             FROM BPM_PROCESOS p 
             JOIN GES_CLIENTES gc ON gc.id = p.cliente_id
             JOIN BPM_IMG_ESTADOS_PROCESOS biep ON biep.id = p.estado_id
             JOIN BPM_TIPOS_PROCESOS btp ON btp.id = p.tipo_id
             WHERE biep.estado IN ('Declaración de imparcialidad','Plan de auditoría','Ejecución Etapa 2','Análisis de NC','Envio Informe Preeliminar','Notificar Complementaria')

             AND p.id = #PROCESO_ID#


      ) AS "ESTADO",
        CURSOR(
              SELECT 
               biep.estado as estado
               
             FROM BPM_PROCESOS p 
             JOIN GES_CLIENTES gc ON gc.id = p.cliente_id
             JOIN BPM_IMG_ESTADOS_PROCESOS biep ON biep.id = p.estado_id
             JOIN BPM_TIPOS_PROCESOS btp ON btp.id = p.tipo_id
             WHERE biep.estado IN ('Programación Ponencia','Declaración de imparcialidad Ponencia','Ejecución Ponencia 1','Ejecución Ponencia 2','Ejecución Ponencia 3','Ejecución Ponencia 4','Ejecución Ponencia 5','Ejecución Ponencia 6','Devolución ponencia1-Ajustes notificación','Devolución ponencia2-Ajustes notificación','Devolución ponencia3-Ajustes notificación','Aprobación ponencia')
             
                      

             AND p.id = #PROCESO_ID#



        ) AS "ESTADO_A",
        CURSOR(
               SELECT 
               biep.estado as estado
               
             FROM BPM_PROCESOS p 
             JOIN GES_CLIENTES gc ON gc.id = p.cliente_id
             JOIN BPM_IMG_ESTADOS_PROCESOS biep ON biep.id = p.estado_id
             JOIN BPM_TIPOS_PROCESOS btp ON btp.id = p.tipo_id
             WHERE biep.estado IN ('Aprobación ponencia para CD')
             
                      

             AND p.id = #PROCESO_ID#

        ) AS "ESTADO_B",
      CURSOR(
            SELECT CODIGO_CONSTANCIA AS NUMERO 
            FROM CONTANCIAS_LOG_COMUNICACIONES 
            WHERE CLIENTE = #RAZON_SOCIAL# AND TIPO_CONSTANCIA = 'De Proceso'
            ORDER BY FECHA_SOLICITUD DESC FETCH FIRST 1 ROW ONLY
       ) AS "CODIGO"
      
    FROM dual
  ) AS "data"
FROM dual;
    !';
    l_return := REPLACE(l_return, '#PROCESO_ID#', TO_CHAR(p_proceso_id));
    l_return := REPLACE(l_return, '#RAZON_SOCIAL#', l_valor_filtrado);
  return l_return;
end;
/

--Envio de correo con constancia de proceso
create or replace PROCEDURE ALERTA_CONSTANCIA_PROCESO_COMUNICACIONES (p_proceso_id NUMBER, p_razon_social VARCHAR2) IS 

v_docx BLOB;
l_response BLOB;
v_mensaje CLOB;
v_mail_id NUMBER;
l_output_filename varchar2(100) := 'Archivo'; 
v_destinatario VARCHAR2(200) := 'esotoe@icontec.org';
v_consecutivo VARCHAR2(300);
v_mail_ejecutivo VARCHAR2(300);


BEGIN

SELECT EMAIL_EJECUTIVO INTO v_mail_ejecutivo FROM BPM_PROCESOS WHERE ID = p_proceso_id;

SELECT CODIGO_CONSTANCIA AS NUMERO 
    INTO v_consecutivo
    FROM CONTANCIAS_LOG_COMUNICACIONES 
    WHERE CLIENTE = p_razon_social AND TIPO_CONSTANCIA = 'De Proceso'
    ORDER BY FECHA_SOLICITUD DESC FETCH FIRST 1 ROW ONLY;
    

v_docx := aop_api_pkg.plsql_call_to_aop(
            p_data_type       => 'PLSQL_SQL',
            p_data_source => 'RETURN CONSTANCIA_PROCESO_COMUNICACIONES('||p_proceso_id||',''' || REPLACE(p_razon_social, '''', '''''') || ''');',
            p_template_type   => 'SQL',
            p_template_source => q'[
                SELECT 'docx', template 
                FROM templates 
                WHERE descripcion = 'Constancia de Proceso'
            ]',
            p_output_type     => 'pdf',
            p_output_filename => l_output_filename,
            p_aop_url         => par('AOP_SERVER'),
            p_api_key         => par('AOP_KEY'),
            p_aop_mode        => par('AOP_MODE'),
            p_app_id          => v('APP_ID'),
            p_aop_remote_debug => 'No'
        );
        
    apex_web_service.g_request_headers(1).name := 'Content-Type';
    apex_web_service.g_request_headers(1).value := 'application/octet-stream';

   l_response := apex_web_service.make_rest_request_b(
      p_url           => 'https://middlewarebackprd.azurewebsites.net/api/v1/pdfBinario',
      p_http_method   => 'POST',
      p_body_blob     => v_docx
   );

    IF l_response IS NOT NULL THEN
    -- Crear el cuerpo del mensaje
        v_mensaje := '<html><body>' ||
                     'Cordial Saludo,<br> '||
                     'De acuerdo con la solicitud registrada, remito la constancia correspondiente para su impresión y posterior entrega al cliente.<br><br>' ||
                     'CONSTANCIA: '||v_consecutivo||'-'||p_razon_social||'<br><br>'||
                     '<u>Nota: Para enviar la constancia en medio magnético al cliente, esta debe estar en papelería oficial de ICONTEC.</u><br><br>' ||
                     '<strong>No olvidar aplicar el sello seco al momento de entregarla en fisico.</strong><br><br>' ||
                     'Gracias.</body></html>';

        -- Enviar correo y capturar ID
        v_mail_id := APEX_MAIL.SEND(
            p_to        => v_mail_ejecutivo,
            p_cc        => 'cpachon@icontec.org',
            p_from      => 'send@icontec.org',
            p_bcc       => 'esotoe@icontec.org',
            p_body      => v_mensaje,
            p_body_html => v_mensaje,
            p_subj      => 'Solicitud de Constancia CORREO ELECTRONICO GENERADO PARA PRUEBA'
        );

        -- Adjuntar DOCX
         APEX_MAIL.ADD_ATTACHMENT(
            p_mail_id    => v_mail_id,
            p_attachment => l_response,
            p_filename   => 'Constancia Proceso.pdf',
            p_mime_type  => 'application/pdf'
        );

        -- Enviar correo
        APEX_MAIL.PUSH_QUEUE;
    END IF;
    COMMIT;




   END;
/

--Geracion de constancia de certificado
create or replace FUNCTION CONSTANCIA_CERTIFICADO_COMUNICACIONES (p_razon_social VARCHAR2) RETURN CLOB IS 
  l_return CLOB;
  l_valor_filtrado VARCHAR2(4000);
BEGIN
  -- Escapar comillas y envolver entre comillas simples
  l_valor_filtrado := '''' || REPLACE(p_razon_social, '''', '''''') || '''';

  l_return := q'!
    SELECT 
      'certificado_info' AS "filename",
      CURSOR(
        SELECT 
          CURSOR(
            SELECT
              TO_CHAR(SYSDATE, 'DD "de" FMmonth "del" YYYY', 'NLS_DATE_LANGUAGE=SPANISH') AS FECHA_ACTUAL,
              (SELECT razon_social 
               FROM GES_CLIENTE_RAZON_SOCIAL 
               WHERE id = c.razon_social_id) AS RAZON_SOCIAL,
              (SELECT ID_FISCAL_PPM 
               FROM GES_CLIENTES 
               WHERE id = c.cliente_id) AS NIT
            FROM GES_CERTIFICADOS c
            WHERE (c.duplicado IS NULL OR c.duplicado = 0)
              AND c.razon_social_id IN (
                SELECT id FROM GES_CLIENTE_RAZON_SOCIAL
                WHERE razon_social = #RAZON_SOCIAL# AND ROWNUM = 1
              ) FETCH FIRST 1 ROW ONLY
          ) AS "CONS_CERTIFICADO",

          CURSOR(
            SELECT
              c.DIRECCION_CLIENTE AS DIRECCION,
              c.ALCANCE_ESPANOL AS ALCANCE,
              c.NUMERO_CERTIFICADO AS CERTIFICADO,
              (select nombre from ges_normas_tecnicas where id = c.norma_id) AS NORMA,
              TO_CHAR(c.FECHA_OTORGAMIENTO,'DD/MM/YYYY') AS FECHA_OTORGAMIENTO,
              TO_CHAR(c.FECHA_VENCIMIENTO,'DD/MM/YYYY') AS FECHA_VENCIMIENTO
            FROM GES_CERTIFICADOS c
            WHERE (c.duplicado IS NULL OR c.duplicado = 0)
              AND c.razon_social_id IN (
                SELECT id FROM GES_CLIENTE_RAZON_SOCIAL
                WHERE razon_social = #RAZON_SOCIAL#
              )
              AND c.estado_id IN (4,55)
          ) AS "CERTIFICADOS",

          CURSOR(
            SELECT CODIGO_CONSTANCIA AS NUMERO 
            FROM CONTANCIAS_LOG_COMUNICACIONES 
            WHERE CLIENTE = #RAZON_SOCIAL# AND TIPO_CONSTANCIA = 'De Certificados'
            ORDER BY FECHA_SOLICITUD DESC FETCH FIRST 1 ROW ONLY
          ) AS "CODIGO"

        FROM dual
      ) AS "data"
    FROM dual;
  !';

  -- Reemplazo limpio y seguro
  l_return := REPLACE(l_return, '#RAZON_SOCIAL#', l_valor_filtrado);
  RETURN l_return;
END;

--Envio de correo con constancia de certificado


create or replace PROCEDURE ALERTA_CONSTANCIA_CERTIFICADO_COMUNICACIONES (p_razon_social VARCHAR2) IS 

v_docx BLOB;
l_response BLOB;
v_mensaje CLOB;
v_mail_id NUMBER;
l_output_filename varchar2(100) := 'Archivo'; 
v_destinatario VARCHAR2(200) := 'esotoe@icontec.org';
v_consecutivo VARCHAR2(300);
cursor c_extract_proceso_id (p_razon_social VARCHAR2) is (SELECT
              c.proceso_id as proceso_id
              
            FROM GES_CERTIFICADOS c
            WHERE (c.duplicado IS NULL OR c.duplicado = 0)
              AND c.razon_social_id IN (
                SELECT id FROM GES_CLIENTE_RAZON_SOCIAL
                WHERE razon_social = p_razon_social
              )
            and c.proceso_id is not null fetch first 1 row only);
    v_proceso_id NUMBER;
    v_mail_ejecutivo VARCHAR2(200);

BEGIN

 OPEN c_extract_proceso_id(p_razon_social);
 FETCH c_extract_proceso_id INTO v_proceso_id;
 CLOSE c_extract_proceso_id;

SELECT EMAIL_EJECUTIVO INTO v_mail_ejecutivo FROM BPM_PROCESOS WHERE ID = v_proceso_id;

    SELECT CODIGO_CONSTANCIA AS NUMERO 
    INTO v_consecutivo
    FROM CONTANCIAS_LOG_COMUNICACIONES 
    WHERE CLIENTE = p_razon_social AND TIPO_CONSTANCIA = 'De Certificados'
    ORDER BY FECHA_SOLICITUD DESC FETCH FIRST 1 ROW ONLY;

v_docx := aop_api_pkg.plsql_call_to_aop(
            p_data_type       => 'PLSQL_SQL',
            p_data_source => 'RETURN CONSTANCIA_CERTIFICADO_COMUNICACIONES(''' || REPLACE(p_razon_social, '''', '''''') || ''');',
            p_template_type   => 'SQL',
            p_template_source => q'[
                SELECT 'docx', template 
                FROM templates 
                WHERE descripcion = 'Constancia de Certificacion'
            ]',
            p_output_type     => 'pdf',
            p_output_filename => l_output_filename,
            p_aop_url         => par('AOP_SERVER'),
            p_api_key         => par('AOP_KEY'),
            p_aop_mode        => par('AOP_MODE'),
            p_app_id          => v('APP_ID'),
            p_aop_remote_debug => 'No'
        );
        
    apex_web_service.g_request_headers(1).name := 'Content-Type';
    apex_web_service.g_request_headers(1).value := 'application/octet-stream';

   l_response := apex_web_service.make_rest_request_b(
      p_url           => 'https://middlewarebackprd.azurewebsites.net/api/v1/pdfBinario',
      p_http_method   => 'POST',
      p_body_blob     => v_docx
   );

    IF l_response IS NOT NULL THEN
    -- Crear el cuerpo del mensaje
        v_mensaje := '<html><body>' ||
                     'Cordial Saludo,<br> '||
                     'De acuerdo con la solicitud registrada, remito la constancia correspondiente para su impresión y posterior entrega al cliente.<br><br>' ||
                     'CONSTANCIA: '||v_consecutivo||'-'||p_razon_social||'<br><br>'||
                     '<u>Nota: Para enviar la constancia en medio magnético al cliente, esta debe estar en papelería oficial de ICONTEC.</u><br><br>' ||
                     '<strong>No olvidar aplicar el sello seco al momento de entregarla en fisico.</strong><br><br>' ||
                     'Gracias.</body></html>';

        -- Enviar correo y capturar ID
        v_mail_id := APEX_MAIL.SEND(
            p_to        => v_mail_ejecutivo,
            p_cc        => 'cpachon@icontec.org',
            p_from      => 'send@icontec.org',
            p_bcc       => 'esotoe@icontec.org',
            p_body      => v_mensaje,
            p_body_html => v_mensaje,
            p_subj      => 'Solicitud de Constancia CORREO ELECTRONICO GENERADO PARA PRUEBA'
        );

        -- Adjuntar DOCX
         APEX_MAIL.ADD_ATTACHMENT(
            p_mail_id    => v_mail_id,
            p_attachment => l_response,
            p_filename   => 'Constancia Certificado.pdf',
            p_mime_type  => 'application/pdf'
        );

        -- Enviar correo
        APEX_MAIL.PUSH_QUEUE;
    END IF;
    COMMIT;




   END;


--Creacion de tabla para feeback auditor

  CREATE TABLE "FEEDBACK_AUDITOR" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"GUID" VARCHAR2(100), 
	"CLIENTE" VARCHAR2(1000), 
	"DETALLE_SOLICITUD" VARCHAR2(5000), 
	"FECHA_REGISTRO" TIMESTAMP (6), 
	"USUARIO" VARCHAR2(500), 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   ) ;

--Trigger para generacion de guid 
  CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_FEEDBACK_GUID" 
BEFORE INSERT ON FEEDBACK_AUDITOR
FOR EACH ROW
DECLARE
  v_num NUMBER;
BEGIN
  SELECT NVL(MAX(TO_NUMBER(GUID)), 0) + 1 INTO v_num
  FROM FEEDBACK_AUDITOR;

  :NEW.GUID := LPAD(v_num, 4, '0');
  
  :NEW.USUARIO := v('APP_USER');
END;
/
ALTER TRIGGER "TRG_FEEDBACK_GUID" ENABLE;


--Alerta para cuando se crea un feedback auditor
create or replace PROCEDURE ALERTA_FEEDBACK_AUDITOR (
  p_proceso_id    VARCHAR2,
  p_auditor        VARCHAR2,
  p_ejecutivo      VARCHAR2
) AS
  v_razon_social VARCHAR2(1000);
  v_nombre_ejecutivo VARCHAR2(200);
  v_mail_ejecutivo VARCHAR2(500);
  v_destinatario VARCHAR2(1000) := 'esotoe@icontec.org';
  v_mensaje      CLOB;
  v_auditor     VARCHAR2(200);
BEGIN
    SELECT bpm.EMAIL_EJECUTIVO, bpm.EJECUTIVO, ges.RAZON_SOCIAL 
    INTO  v_mail_ejecutivo, v_nombre_ejecutivo, v_razon_social
    FROM BPM_PROCESOS bpm
    LEFT JOIN GES_CERTIFICADOS ges ON ges.PROCESO_ID = bpm.id
    WHERE bpm.ID = p_proceso_id;
    select NOMBRES ||' '||APELLIDOS INTO v_auditor FROM USUARIOS WHERE USERNAME = p_auditor;
  -- Construcción del cuerpo del mensaje
  v_mensaje := 
    '<html><body>' ||
    'Estimado/a ' || v_nombre_ejecutivo || '.<br><br>' || CHR(10) ||
    'Le informamos que el profesional <b>' || v_auditor || '</b> ha registrado una nueva oportunidad de negocio como resultado de la auditoría realizada al cliente <b>' || v_razon_social || '</b>.<br>' || CHR(10) ||
    'Le invitamos a revisar el detalle del registro en el Módulo de Comunicaciones para dar seguimiento oportuno.<br><br>' || CHR(10) ||

    '<a href="https://ga6d8915c217411-icontecbdautonomousatp.adb.us-ashburn-1.oraclecloudapps.com/ords/r/iconsenddev/aplicacion-junio-sg-comunicaciones/home?session=310671512111882" style="' ||
      'display:inline-block;' ||
      'padding:10px 20px;' ||
      'background-color:#007acc;' ||
      'color:#ffffff;' ||
      'text-decoration:none;' ||
      'border-radius:5px;' ||
      'font-weight:bold;' ||
      'font-family:Arial, sans-serif;' ||
      '">Ver Detalle</a><br><br>' ||

    'Gracias por su atención.<br>' ||
    '</body></html>';

  -- Enviar correo
  APEX_MAIL.SEND(
    p_to        => v_mail_ejecutivo,
    p_from      => 'send@icontec.org',
    p_cc        => 'cpachon@icontec.org',
    p_bcc       => v_destinatario,
    p_subj      => 'Nueva Oportunidad de Negocio',
    p_body      => v_mensaje,
    p_body_html => v_mensaje
  );

  -- Forzar envío del correo
  APEX_MAIL.PUSH_QUEUE;
END;
/

--Modulo accidentes acreditacion
--Creacion de tabla para accidentes laborales
  CREATE TABLE "ACREDITACION_COMUNICACIONES" 
   (	"NO_SOLICITUD" NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"CLIENTE" NUMBER NOT NULL ENABLE, 
	"DETALLE" VARCHAR2(4000), 
	"ADJUNTO" BLOB, 
	"ADJUNTO_FILENAME" VARCHAR2(255), 
	"ADJUNTO_MIME_TYPE" VARCHAR2(255), 
	"CREATED" DATE, 
	"CREATED_BY" VARCHAR2(100), 
	"UPDATED" DATE, 
	"UPDATED_BY" VARCHAR2(100), 
	 PRIMARY KEY ("NO_SOLICITUD")
  USING INDEX  ENABLE
   ) ;
--Creacion de FK para relacion al cliente
  ALTER TABLE "ACREDITACION_COMUNICACIONES" ADD CONSTRAINT "FK_ACRED_COM_CLIENTE" FOREIGN KEY ("CLIENTE")
	  REFERENCES "GES_CLIENTES" ("ID") ENABLE;
--Creacion de trigger para enviar correo
  CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_COMU_SEND_EMAIL" 
AFTER INSERT ON ACREDITACION_COMUNICACIONES
FOR EACH ROW
DECLARE
    l_subject     VARCHAR2(200);
    l_body        CLOB;
    l_cliente     VARCHAR2(500);
    l_proceso_id  NUMBER;
    l_recipients  VARCHAR2(4000); -- Lista de correos separados por coma
BEGIN
    -- 1️⃣ Obtener último proceso activo del cliente
    BEGIN
        SELECT bp.id
        INTO l_proceso_id
        FROM bpm_procesos bp
        JOIN bpm_img_estados_procesos bei 
          ON bei.id = bp.estado_id
        WHERE bp.cliente_id = :NEW.cliente
          AND bei.estado NOT IN ('Anulado', 'Proceso Finalizado')
        ORDER BY bp.created DESC
        FETCH FIRST 1 ROWS ONLY;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN; -- No enviar correo si no hay proceso activo
    END;

    -- 2️⃣ Obtener razón social del cliente
    SELECT razon_social
    INTO l_cliente
    FROM ges_clientes
    WHERE id = :NEW.cliente;

     -- Construir cuerpo del correo
    l_subject := 'Nueva comunicación registrada - Cliente ' || l_cliente;
    l_body := '<h3>Se ha registrado una nueva comunicación</h3>' ||
              '<p><b>No. Solicitud:</b> ' || :NEW.no_solicitud || '</p>' ||
              '<p><b>Cliente:</b> ' || l_cliente || '</p>' ||
              '<p><b>Fecha:</b> ' || TO_CHAR(
                    FROM_TZ(CAST(SYSDATE AS TIMESTAMP), SESSIONTIMEZONE) AT TIME ZONE '-05:00',
                    'DD/MM/YYYY HH24:MI') || '</p>' ||
              '<p><b>Usuario:</b> ' || :NEW.created_by || '</p>' ||
              '<p><b>Detalle:</b> ' || :NEW.detalle || '</p>';

    -- Construir lista de destinatarios
    FOR rec IN (
        SELECT DISTINCT email
        FROM (
            -- Auditor líder
            SELECT u.e_mail AS email
            FROM ges_normas_auditor gna
            JOIN ges_auditores_proceso gap ON gap.id = gna.auditor
            JOIN usuarios u ON u.id = gap.auditor
            WHERE gna.lider = 'S'
              AND gap.proceso_id = l_proceso_id

            UNION
            -- Coordinador de Servicio
            SELECT u.e_mail AS email
            FROM ges_auditores_proceso gap
            JOIN usuarios u ON u.id = gap.auditor
            WHERE gap.coordinador = 'S'
              AND gap.proceso_id = l_proceso_id

            UNION
            -- Auxiliar que creó el caso
            SELECT u.e_mail AS email
            FROM usuarios u
            WHERE u.username = :NEW.created_by

            UNION
            -- Ejecutivo de Cuenta
            SELECT bp.email_ejecutivo AS email
            FROM bpm_procesos bp
            WHERE bp.id = l_proceso_id
        )
        WHERE email IS NOT NULL
    ) LOOP
        IF l_recipients IS NULL THEN
            l_recipients := rec.email;
        ELSE
            l_recipients := l_recipients || ',' || rec.email;
        END IF;
    END LOOP;

    -- Enviar un solo correo a todos
    DECLARE
        l_mail_id NUMBER;
    BEGIN
        l_mail_id := APEX_MAIL.SEND(
            p_to        => l_recipients,
            p_bcc       => 'jcespedes@icontec.org',
            p_from      => 'send@icontec.org',
            p_subj      => l_subject,
            p_body      => l_body,
            p_body_html => l_body
        );

        IF :NEW.adjunto IS NOT NULL THEN
            APEX_MAIL.ADD_ATTACHMENT(
                p_mail_id    => l_mail_id,
                p_attachment => :NEW.adjunto,
                p_filename   => :NEW.adjunto_filename,
                p_mime_type  => :NEW.adjunto_mime_type
            );
        END IF;
    END;

    -- Enviar la cola
    APEX_MAIL.PUSH_QUEUE;
    
EXCEPTION
    WHEN OTHERS THEN
        APEX_DEBUG.ERROR('Error en trigger comunicaciones: ' || SQLERRM);
END;
/
--Trigger para registro de log 
ALTER TRIGGER "TRG_COMU_SEND_EMAIL" ENABLE;
  CREATE OR REPLACE EDITIONABLE TRIGGER "ACC_LABO_TRV_BIU" 
    before insert or update  
    on ACREDITACION_COMUNICACIONES 
    for each row 
begin 
    if inserting then 
        :new.created := sysdate; 
        :new.created_by := nvl(sys_context('APEX$SESSION','APP_USER'),user); 
    end if; 
    :new.updated := sysdate; 
    :new.updated_by := nvl(sys_context('APEX$SESSION','APP_USER'),user); 
end ACC_LABO_TRV_BIU;
/
ALTER TRIGGER "ACC_LABO_TRV_BIU" ENABLE;


--Modulo testificaciones 

--Creacion de tabla testificaciones
  CREATE TABLE "ACREDITACION_COMUNICACIONES_TESTIFICACIONES" 
   (	"NO_SOLICITUD" NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"CLIENTE" NUMBER NOT NULL ENABLE, 
	"DETALLE" VARCHAR2(4000), 
	"ADJUNTO" BLOB, 
	"ADJUNTO_FILENAME" VARCHAR2(255), 
	"ADJUNTO_MIME_TYPE" VARCHAR2(255), 
	"CREATED" DATE, 
	"CREATED_BY" VARCHAR2(100), 
	"UPDATED" DATE, 
	"UPDATED_BY" VARCHAR2(100), 
	"BPM_PROCESO_ID" NUMBER NOT NULL ENABLE, 
	 PRIMARY KEY ("NO_SOLICITUD")
  USING INDEX  ENABLE
   ) ;
--Creacion de FK para relacion al cliente
  ALTER TABLE "ACREDITACION_COMUNICACIONES_TESTIFICACIONES" ADD CONSTRAINT "FK_ACRED_COM_TESTI_CLIENTE" FOREIGN KEY ("CLIENTE")
	  REFERENCES "GES_CLIENTES" ("ID") ENABLE;
--Creacion de trigger para auditoria
  CREATE OR REPLACE EDITIONABLE TRIGGER "ACC_LABO_TRV_BIU_TEST" 
    before insert or update  
    on ACREDITACION_COMUNICACIONES_TESTIFICACIONES 
    for each row 
begin 
    if inserting then 
        :new.created := sysdate; 
        :new.created_by := nvl(sys_context('APEX$SESSION','APP_USER'),user); 
    end if; 
    :new.updated := sysdate; 
    :new.updated_by := nvl(sys_context('APEX$SESSION','APP_USER'),user); 
end ACC_LABO_TRV_BIU_TEST;
/

--Trigger para envio de correo de notificacion
ALTER TRIGGER "ACC_LABO_TRV_BIU_TEST" ENABLE;
  CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_TEST_SEND_EMAIL" 
AFTER INSERT ON ACREDITACION_COMUNICACIONES_TESTIFICACIONES
FOR EACH ROW
DECLARE
    l_subject                VARCHAR2(200);
    l_body                   CLOB;
    l_cliente                VARCHAR2(500);
    l_estado_proceso_actual VARCHAR2(200);
    l_tiene_proceso_activo  NUMBER := 0;
    l_recipients             VARCHAR2(4000); -- Lista de correos separados por coma
BEGIN
    -- 1️⃣ Estado del proceso actual
    SELECT bei.estado
    INTO l_estado_proceso_actual
    FROM bpm_procesos bp
    JOIN bpm_img_estados_procesos bei 
      ON bei.id = bp.estado_id
    WHERE bp.id = :NEW.bpm_proceso_id;

    -- 2️⃣ Verificar si el cliente tiene algún proceso activo
    SELECT CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
    INTO l_tiene_proceso_activo
    FROM bpm_procesos bp
    JOIN bpm_img_estados_procesos bei 
      ON bei.id = bp.estado_id
    WHERE bp.cliente_id = :NEW.cliente
      AND bei.estado NOT IN ('Anulado', 'Proceso Finalizado');

    -- 3️⃣ Si no cumple al menos una de las condiciones → salir
    IF (l_estado_proceso_actual IN ('Anulado', 'Proceso Finalizado'))
       AND (l_tiene_proceso_activo = 0) THEN
        RETURN;
    END IF;

    -- 4️⃣ Obtener razón social del cliente
    SELECT razon_social
    INTO l_cliente
    FROM ges_clientes
    WHERE id = :NEW.cliente;

    -- 5️⃣ Asunto y cuerpo HTML con hora en GMT-5
    l_subject := 'Nueva Testificación registrada - Cliente ' || l_cliente;
    l_body := '<h3>Se ha registrado una nueva Testificación</h3>' ||
              '<p><b>No. Solicitud:</b> ' || :NEW.no_solicitud || '</p>' ||
              '<p><b>Cliente:</b> ' || l_cliente || '</p>' ||
              '<p><b>Fecha:</b> ' || TO_CHAR(
                    FROM_TZ(CAST(SYSDATE AS TIMESTAMP), SESSIONTIMEZONE) AT TIME ZONE '-05:00',
                    'DD/MM/YYYY HH24:MI') || '</p>' ||
              '<p><b>Usuario:</b> ' || :NEW.created_by || '</p>' ||
              '<p><b>Observación:</b> ' || :NEW.detalle || '</p>';

    -- 6️⃣ Construir lista de destinatarios
    FOR rec IN (
        SELECT DISTINCT email
        FROM (
            SELECT u.e_mail AS email
            FROM ges_normas_auditor gna
            JOIN ges_auditores_proceso gap ON gap.id = gna.auditor
            JOIN usuarios u ON u.id = gap.auditor
            WHERE gna.lider = 'S'
              AND gap.proceso_id = :NEW.bpm_proceso_id

            UNION
            SELECT u.e_mail AS email
            FROM ges_auditores_proceso gap
            JOIN usuarios u ON u.id = gap.auditor
            WHERE gap.coordinador = 'S'
              AND gap.proceso_id = :NEW.bpm_proceso_id

            UNION
            SELECT u.e_mail AS email
            FROM usuarios u
            WHERE u.username = :NEW.created_by

            UNION
            SELECT bp.email_ejecutivo AS email
            FROM bpm_procesos bp
            WHERE bp.id = :NEW.bpm_proceso_id
        )
        WHERE email IS NOT NULL
    ) LOOP
        IF l_recipients IS NULL THEN
            l_recipients := rec.email;
        ELSE
            l_recipients := l_recipients || ',' || rec.email;
        END IF;
    END LOOP;

    -- 7️⃣ Enviar un solo correo
    DECLARE
        l_mail_id NUMBER;
    BEGIN
        l_mail_id := APEX_MAIL.SEND(
            p_to        => l_recipients,
            p_bcc       => 'jcespedes@icontec.org',
            p_from      => 'send@icontec.org',
            p_subj      => l_subject,
            p_body      => l_body,
            p_body_html => l_body
        );

        IF :NEW.adjunto IS NOT NULL THEN
            APEX_MAIL.ADD_ATTACHMENT(
                p_mail_id    => l_mail_id,
                p_attachment => :NEW.adjunto,
                p_filename   => :NEW.adjunto_filename,
                p_mime_type  => :NEW.adjunto_mime_type
            );
        END IF;
    END;

    -- 8️⃣ Enviar la cola
    APEX_MAIL.PUSH_QUEUE;

EXCEPTION
    WHEN OTHERS THEN
        APEX_DEBUG.ERROR('Error en trigger Testificaciones: ' || SQLERRM);
END;
/
ALTER TRIGGER "TRG_TEST_SEND_EMAIL" ENABLE;

--Modulo reposiciones 
--Creacion de tabla reposiciones 
  CREATE TABLE "ACREDITACION_COMUNICACIONES_REPOSICIONES" 
   (	"NO_SOLICITUD" NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"CLIENTE" NUMBER NOT NULL ENABLE, 
	"DETALLE" VARCHAR2(4000), 
	"ADJUNTO" BLOB, 
	"ADJUNTO_FILENAME" VARCHAR2(255), 
	"ADJUNTO_MIME_TYPE" VARCHAR2(255), 
	"CREATED" DATE, 
	"CREATED_BY" VARCHAR2(100), 
	"UPDATED" DATE, 
	"UPDATED_BY" VARCHAR2(100), 
	"BPM_PROCESO_ID" NUMBER NOT NULL ENABLE, 
	 PRIMARY KEY ("NO_SOLICITUD")
  USING INDEX  ENABLE
   ) ;
--creacion de FK para relacion al cliente
  ALTER TABLE "ACREDITACION_COMUNICACIONES_REPOSICIONES" ADD CONSTRAINT "FK_ACRED_COM_REPO_CLIENTE" FOREIGN KEY ("CLIENTE")
	  REFERENCES "GES_CLIENTES" ("ID") ENABLE;
--Trigger de auditoria
  CREATE OR REPLACE EDITIONABLE TRIGGER "ACC_LABO_TRV_BIU_REPO" 
    before insert or update  
    on ACREDITACION_COMUNICACIONES_REPOSICIONES 
    for each row 
begin 
    if inserting then 
        :new.created := sysdate; 
        :new.created_by := nvl(sys_context('APEX$SESSION','APP_USER'),user); 
    end if; 
    :new.updated := sysdate; 
    :new.updated_by := nvl(sys_context('APEX$SESSION','APP_USER'),user); 
end ACC_LABO_TRV_BIU_REPO;
/

--Creacion de trigger para envio de notificacion
ALTER TRIGGER "ACC_LABO_TRV_BIU_REPO" ENABLE;
  CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_REPO_SEND_EMAIL" 
AFTER INSERT ON ACREDITACION_COMUNICACIONES_REPOSICIONES
FOR EACH ROW
DECLARE
    l_subject                VARCHAR2(200);
    l_body                   CLOB;
    l_cliente                VARCHAR2(500);
    l_estado_proceso_actual VARCHAR2(200);
    l_tiene_proceso_activo  NUMBER := 0;
    l_recipients             VARCHAR2(4000); -- Lista de correos separados por coma
BEGIN
    -- 1️⃣ Estado del proceso actual
    SELECT bei.estado
    INTO l_estado_proceso_actual
    FROM bpm_procesos bp
    JOIN bpm_img_estados_procesos bei 
      ON bei.id = bp.estado_id
    WHERE bp.id = :NEW.bpm_proceso_id;

    -- 2️⃣ Verificar si el cliente tiene algún proceso activo
    SELECT CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
    INTO l_tiene_proceso_activo
    FROM bpm_procesos bp
    JOIN bpm_img_estados_procesos bei 
      ON bei.id = bp.estado_id
    WHERE bp.cliente_id = :NEW.cliente
      AND bei.estado NOT IN ('Anulado', 'Proceso Finalizado');

    -- 3️⃣ Si no cumple al menos una de las condiciones → salir
    IF (l_estado_proceso_actual IN ('Anulado', 'Proceso Finalizado'))
       AND (l_tiene_proceso_activo = 0) THEN
        RETURN;
    END IF;

    -- 4️⃣ Obtener razón social del cliente
    SELECT razon_social
    INTO l_cliente
    FROM ges_clientes
    WHERE id = :NEW.cliente;

    -- 5️⃣ Asunto y cuerpo HTML con hora en GMT-5
    l_subject := 'Nueva reposición registrada - Cliente ' || l_cliente;
    l_body := '<h3>Se ha registrado una nueva reposición</h3>' ||
              '<p><b>No. Solicitud:</b> ' || :NEW.no_solicitud || '</p>' ||
              '<p><b>Cliente:</b> ' || l_cliente || '</p>' ||
              '<p><b>Fecha:</b> ' || TO_CHAR(
                    FROM_TZ(CAST(SYSDATE AS TIMESTAMP), SESSIONTIMEZONE) AT TIME ZONE '-05:00',
                    'DD/MM/YYYY HH24:MI') || '</p>' ||
              '<p><b>Usuario:</b> ' || :NEW.created_by || '</p>' ||
              '<p><b>Observación:</b> ' || :NEW.detalle || '</p>';

    -- 6️⃣ Construir lista de destinatarios
    FOR rec IN (
        SELECT DISTINCT email
        FROM (
            SELECT u.e_mail AS email
            FROM ges_normas_auditor gna
            JOIN ges_auditores_proceso gap ON gap.id = gna.auditor
            JOIN usuarios u ON u.id = gap.auditor
            WHERE gna.lider = 'S'
              AND gap.proceso_id = :NEW.bpm_proceso_id

            UNION
            SELECT u.e_mail AS email
            FROM ges_auditores_proceso gap
            JOIN usuarios u ON u.id = gap.auditor
            WHERE gap.coordinador = 'S'
              AND gap.proceso_id = :NEW.bpm_proceso_id

            UNION
            SELECT u.e_mail AS email
            FROM usuarios u
            WHERE u.username = :NEW.created_by

            UNION
            SELECT bp.email_ejecutivo AS email
            FROM bpm_procesos bp
            WHERE bp.id = :NEW.bpm_proceso_id
        )
        WHERE email IS NOT NULL
    ) LOOP
        IF l_recipients IS NULL THEN
            l_recipients := rec.email;
        ELSE
            l_recipients := l_recipients || ',' || rec.email;
        END IF;
    END LOOP;

    -- 7️⃣ Enviar un solo correo
    DECLARE
        l_mail_id NUMBER;
    BEGIN
        l_mail_id := APEX_MAIL.SEND(
            p_to        => l_recipients,
            p_bcc       => 'jcespedes@icontec.org',
            p_from      => 'send@icontec.org',
            p_subj      => l_subject,
            p_body      => l_body,
            p_body_html => l_body
        );

        IF :NEW.adjunto IS NOT NULL THEN
            APEX_MAIL.ADD_ATTACHMENT(
                p_mail_id    => l_mail_id,
                p_attachment => :NEW.adjunto,
                p_filename   => :NEW.adjunto_filename,
                p_mime_type  => :NEW.adjunto_mime_type
            );
        END IF;
    END;

    -- 8️⃣ Enviar la cola
    APEX_MAIL.PUSH_QUEUE;

EXCEPTION
    WHEN OTHERS THEN
        APEX_DEBUG.ERROR('Error en trigger reposiciones: ' || SQLERRM);
END;
/
ALTER TRIGGER "TRG_REPO_SEND_EMAIL" ENABLE;

--Modulo de Servicio al cliente

--Modulo de quejas
--Creacuib de tabla para registro de quejas
  CREATE TABLE "REGISTRO_QUEJAS_COMUNICACIONES" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"CODIGO_QUEJA" VARCHAR2(10), 
	"FECHA_REGISTRO" TIMESTAMP (6) DEFAULT SYSTIMESTAMP, 
	"USUARIO_REPORTA" VARCHAR2(100), 
	"CLIENTE" VARCHAR2(200), 
	"CANAL_REPORTE" VARCHAR2(100), 
	"TIPO_QUEJA" VARCHAR2(100), 
	"DESCRIPCION" VARCHAR2(4000), 
	"ESTADO" VARCHAR2(50), 
	"RESPONSABLE" VARCHAR2(100), 
	"FECHA_SOLUCION" TIMESTAMP (6), 
	"COMENTARIO_CIERRE" VARCHAR2(1000), 
	"QUEJA_TYPE" VARCHAR2(100), 
	"NOMBRE_ARCHIVO" VARCHAR2(255), 
	"MIME_TYPE_ARCHIVO" VARCHAR2(255), 
	"ARCHIVO_ADJUNTO" BLOB, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   ) ;
--Creacion de trigger para manejo de codigo quejas y las quejas de terceros

  CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_QUEJAS_GUID" 
BEFORE INSERT ON REGISTRO_QUEJAS_COMUNICACIONES
FOR EACH ROW
DECLARE
  v_num NUMBER;
BEGIN
  IF :NEW.QUEJA_TYPE = 'Queja' THEN 
  SELECT NVL(MAX(TO_NUMBER(CODIGO_QUEJA)), 0) + 1 INTO v_num 
  FROM REGISTRO_QUEJAS_COMUNICACIONES WHERE QUEJA_TYPE = 'Queja';

  :NEW.CODIGO_QUEJA := LPAD(v_num, 4, '0');

  INSERT INTO NOTIFICACIONES_COMUNICACIONES (MENSAJE,RESPUESTA,USUARIO_CREADOR) VALUES ( :NEW.CODIGO_QUEJA,:NEW.QUEJA_TYPE,v('APP_USER'));


  ELSE 

  SELECT NVL(MAX(TO_NUMBER(CODIGO_QUEJA)), 0) + 1 INTO v_num 
  FROM REGISTRO_QUEJAS_COMUNICACIONES WHERE QUEJA_TYPE = 'Queja Tercero';

  :NEW.CODIGO_QUEJA := LPAD(v_num, 4, '0');

  INSERT INTO NOTIFICACIONES_COMUNICACIONES (MENSAJE,RESPUESTA,USUARIO_CREADOR) VALUES ( :NEW.CODIGO_QUEJA,:NEW.QUEJA_TYPE,v('APP_USER'));
  END IF;

END;
/
ALTER TRIGGER "TRG_QUEJAS_GUID" ENABLE;

--Modulo de incidencias y comentarios
--Creacion de tabla para registro de incidencias/Comunicaciones

  CREATE TABLE "REGISTRO_INCIDENCIAS_COMUNICACIONES" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"FECHA_REGISTRO" TIMESTAMP (6) DEFAULT SYSTIMESTAMP, 
	"USUARIO_REPORTA" VARCHAR2(100), 
	"TIPO_INCIDENCIA" VARCHAR2(100), 
	"DESCRIPCION" VARCHAR2(4000), 
	"RESPONSABLE" VARCHAR2(100), 
	"FECHA_SOLUCION" TIMESTAMP (6), 
	"COMENTARIO_CIERRE" VARCHAR2(1000), 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   ) ;

--Creacion de tabla para reflejo de notificaciones

CREATE TABLE .NOTIFICACIONES_COMUNICACIONES (
  ID NUMBER GENERATED ALWAYS AS IDENTITY START WITH 1 INCREMENT BY 1,
  PRIMARY KEY(ID), 

  DISPOSITIVO_USUARIO NUMBER,                   -- FK opcional hacia DISPOSITIVOS_USUARIOS
  FECHA DATE,                                    -- Fecha de la notificación
  MENSAJE VARCHAR2(2000 BYTE) NOT NULL,         -- Contenido principal
  RESPUESTA VARCHAR2(300 BYTE),                 -- Respuesta del usuario (si aplica)
  ENLACE VARCHAR2(500 BYTE),                    -- URL o referencia asociada
  CREATED DATE NOT NULL,                        -- Fecha de creación
  CREATED_BY VARCHAR2(255 BYTE) NOT NULL,       -- Usuario que creó el registro
  UPDATED DATE NOT NULL,                        -- Fecha de última modificación
  UPDATED_BY VARCHAR2(255 BYTE) NOT NULL,       -- Usuario que modificó
  USUARIO_CREADOR VARCHAR2(1000 BYTE),          -- Usuario lógico o externo
  DETALLLE VARCHAR2(5000 BYTE)                 

);


--Creacion de tabla para guardar el source del panel lateral

  CREATE TABLE "SOURCE_FOOTER_NOTICIAS_MODULO_COMUNICACIONES" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"SOURCE" CLOB, 
	"TIPO" VARCHAR2(200), 
	"ARCHIVO_CONTENT" BLOB, 
	"MIME_TYPE" VARCHAR2(2000), 
	"FILE_NAME" VARCHAR2(2000), 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   ) ;


--Creacion de funntion para previsualizacion de carta suspension administrativa normal

create or replace function GET_SQL_SUSPENSION_ADMINISTRATIVA_SG   (CERTIF_ID_AOP in number)
return BLOB   
is   
l_return blob;   
l_output_filename varchar2(255) := 'Carta suspensión administrativa';   
v_number number;  
begin   
  begin
  insert into SEG_OFFICE_PRINT(PAGINA,FUNCION)
    values('DESDE LA FUNCION','GET_PDF_SUSPENSION_ADMINISTRATIVASG1');
    end;
  
  
l_return := aop_api_pkg.plsql_call_to_aop (   
                p_data_type       => 'PLSQL_SQL',   
                p_data_source     => 'return SQL_SUSPENSION_ADMINISTRATIVA_SG1('||CERTIF_ID_AOP||')',    
                p_template_type   => 'SQL',   
                p_template_source => q'[   
                   select 'docx', template   
                    from templates    
                    where descripcion = 'Plantilla Seguimiento N'                      
                ]',   
                p_output_type     => 'pdf',   
                p_output_filename => l_output_filename,                   
                p_aop_url         => par('AOP_SERVER'),
		p_api_key         => par('AOP_KEY'), 
        p_aop_mode        => par('AOP_MODE'),                   
                p_app_id          => v('APP_ID'));   
                    
return l_return;   
end;
/


--Creacion de funntion para previsualizacion de carta suspension administrativa 1

create or replace function GET_SQL_SUSPENSION_ADMINISTRATIVA_SG1   (CERTIF_ID_AOP in number)
return BLOB   
is   
l_return blob;   
l_output_filename varchar2(255) := 'Carta suspensión administrativa';   
v_number number;  
begin   
  begin
  insert into SEG_OFFICE_PRINT(PAGINA,FUNCION)
    values('DESDE LA FUNCION','GET_PDF_SUSPENSION_ADMINISTRATIVASG1');
    end;
  
  
l_return := aop_api_pkg.plsql_call_to_aop (   
                p_data_type       => 'PLSQL_SQL',   
                p_data_source     => 'return SQL_SUSPENSION_ADMINISTRATIVA_SG1('||CERTIF_ID_AOP||')',    
                p_template_type   => 'SQL',   
                p_template_source => q'[   
                   select 'docx', template   
                    from templates    
                    where descripcion = 'Plantilla Seguimiento 1'                      
                ]',   
                p_output_type     => 'pdf',   
                p_output_filename => l_output_filename,                   
                p_aop_url         => par('AOP_SERVER'),
		p_api_key         => par('AOP_KEY'), 
        p_aop_mode        => par('AOP_MODE'),                   
                p_app_id          => v('APP_ID'));   
                    
return l_return;   
end;
/

--Envio de carga para suspension sg 1
create or replace procedure "ENVIAR_CARTA_SUSPENSION_ADMINISTRATIVA_SG1"    
(p_norma_id IN NUMBER,
p_certificado_id in number)    
is    
   v_proceso number;    
   v_carta blob;    
   v_correo_cliente varchar2(255);    
   v_oportunidad varchar2(255);    
   v_cpq varchar2(255);    
   v_number number;    
   v_correo_tecnico varchar2(2000); 
   l_response blob;
   l_output_filename VARCHAR2(2000):= 'suspension';
begin    
    
v_number := par('CONSECUTIVO_SUSPENSIONES');    
    
v_number := v_number + 1;    
    
update parametros    
set valor = v_number    
where nombre = 'CONSECUTIVO_SUSPENSIONES';    
    
    
    select np.proceso_id     
    into v_proceso    
    from ges_normas_procesos np        
    where np.id=p_norma_id;    
        
    select ge1.mail, nvl(p1.email_ejecutivo,par('MAIL_FROM')) e_oportunidad, nvl(p1.mail_dueno_cpq,par('MAIL_FROM')) e_cpq    
    into v_correo_cliente,v_oportunidad,v_cpq   
    from GES_CONTACTOS_PROCESO ge1,   
         GES_CLIENTES_PROCESO g1,   
         bpm_procesos p1   
     where ge1.cliente_id = g1.id   
     and g1.proceso_id = p1.id   
     and p1.id = v_proceso
     and ge1.principal='S'   and rownum <= 1;     
    
    if (PAR('ENVIO_CORREOS_CLIENTES')='N') then    
       v_correo_cliente:='jorjuela@mboingenieria.com';    
    end if;    
    
    select LISTAGG(DISTINCT NVL(U.E_MAIL,PAR('MAIL_FROM')),',')    
into v_correo_tecnico    
from usuarios u    
    ,usuarios_roles ur    
    ,roles r    
where ur.usuario = u.id    
and ur.rol=r.id        
and r.rol = 'TECNICO_OPERACIONES';    
    
    v_carta := aop_api_pkg.plsql_call_to_aop (   
                p_data_type       => 'PLSQL_SQL',   
                p_data_source     => 'return SQL_SUSPENSION_ADMINISTRATIVA_SG1('||p_certificado_id||')',    
                p_template_type   => 'SQL',   
                p_template_source => q'[   
                   select 'docx', template   
                    from templates    
                    where descripcion = 'Plantilla Seguimiento 1'                      
                ]',   
                p_output_type     => 'pdf',   
                p_output_filename => l_output_filename,                   
                p_aop_url         => par('AOP_SERVER'),
		p_api_key         => par('AOP_KEY'), 
        p_aop_mode        => par('AOP_MODE'),                   
                p_app_id          => v('APP_ID'));
     

         

    l_response := apex_web_service.make_rest_request_b(
      p_url           => 'https://middlewarebackprd.azurewebsites.net/api/v1/pdfBinario',
      p_http_method   => 'POST',
      p_body_blob     => v_carta
   );


    DECLARE     
    l_id NUMBER;     
    l_body clob;     
BEGIN     
         
  
l_body := 'Cordial Saludo,<br/>    
Amablemente adjuntamos comunicación con asunto Suspensión Administrativa con el fin de atender las disposiciones dadas.<br/><br/>
Gracias.<br/><br/>SEND';
    
     
    l_id := APEX_MAIL.SEND( 
        -- p_to        => 'esotoe@icontec.org',   
        p_to        => v_correo_cliente,     
        p_from      => par('MAIL_FROM'),     
        p_cc => v_oportunidad||','||v_cpq||','||'yquiroz@icontec.org',     
        p_bcc => par('MAIL_FROM'),     
        p_subj      => 'Suspensión Administrativa CORREO ELECTRONICO GENERADO PARA PRUEBAS',     
        p_body      => l_body,     
        p_body_html => l_body);     
         
        APEX_MAIL.ADD_ATTACHMENT(     
            p_mail_id    => l_id,     
            p_attachment => l_response,     
            p_filename   => 'Carta Suspension Administrativa.pdf',     
            p_mime_type  => 'application/pdf');     
             
         
  end;     
  apex_mail.push_queue;   
end;
/
--Envio de carga para suspension normal

create or replace procedure "ENVIAR_CARTA_SUSPENSION_ADMINISTRATIVA_SGN"    
(p_norma_id IN NUMBER,
p_certificado_id in number)    
is    
   v_proceso number;    
   v_carta blob;    
   v_correo_cliente varchar2(255);    
   v_oportunidad varchar2(255);    
   v_cpq varchar2(255);    
   v_number number;    
   v_correo_tecnico varchar2(2000); 
   l_response blob;
   l_output_filename VARCHAR2(2000):= 'suspension';
begin    
    
v_number := par('CONSECUTIVO_SUSPENSIONES');    
    
v_number := v_number + 1;    
    
update parametros    
set valor = v_number    
where nombre = 'CONSECUTIVO_SUSPENSIONES';    
    
    
    select np.proceso_id     
    into v_proceso    
    from ges_normas_procesos np        
    where np.id=p_norma_id;    
        
    select ge1.mail, nvl(p1.email_ejecutivo,par('MAIL_FROM')) e_oportunidad, nvl(p1.mail_dueno_cpq,par('MAIL_FROM')) e_cpq    
    into v_correo_cliente,v_oportunidad,v_cpq   
    from GES_CONTACTOS_PROCESO ge1,   
         GES_CLIENTES_PROCESO g1,   
         bpm_procesos p1   
     where ge1.cliente_id = g1.id   
     and g1.proceso_id = p1.id   
     and p1.id = v_proceso
     and ge1.principal='S'   and rownum <= 1;     
    
    if (PAR('ENVIO_CORREOS_CLIENTES')='N') then    
       v_correo_cliente:='jorjuela@mboingenieria.com';    
    end if;    
    
    select LISTAGG(DISTINCT NVL(U.E_MAIL,PAR('MAIL_FROM')),',')    
into v_correo_tecnico    
from usuarios u    
    ,usuarios_roles ur    
    ,roles r    
where ur.usuario = u.id    
and ur.rol=r.id        
and r.rol = 'TECNICO_OPERACIONES';    
    
    v_carta := aop_api_pkg.plsql_call_to_aop (   
                p_data_type       => 'PLSQL_SQL',   
                p_data_source     => 'return SQL_SUSPENSION_ADMINISTRATIVA_SG1('||p_certificado_id||')',    
                p_template_type   => 'SQL',   
                p_template_source => q'[   
                   select 'docx', template   
                    from templates    
                    where descripcion = 'Plantilla Seguimiento N'                      
                ]',   
                p_output_type     => 'pdf',   
                p_output_filename => l_output_filename,                   
                p_aop_url         => par('AOP_SERVER'),
		p_api_key         => par('AOP_KEY'), 
        p_aop_mode        => par('AOP_MODE'),                   
                p_app_id          => v('APP_ID'));
     

         

    l_response := apex_web_service.make_rest_request_b(
      p_url           => 'https://middlewarebackprd.azurewebsites.net/api/v1/pdfBinario',
      p_http_method   => 'POST',
      p_body_blob     => v_carta
   );


    DECLARE     
    l_id NUMBER;     
    l_body clob;     
BEGIN     
         
  
l_body := 'Cordial Saludo,<br/>    
Amablemente adjuntamos comunicación con asunto Suspensión Administrativa con el fin de atender las disposiciones dadas.<br/><br/>
Gracias.<br/><br/>SEND';
    
     
    l_id := APEX_MAIL.SEND( 
        -- p_to        => 'esotoe@icontec.org',   
        p_to        => v_correo_cliente,     
        p_from      => par('MAIL_FROM'),     
        p_cc => v_oportunidad||','||v_cpq||','||'yquiroz@icontec.org',     
        p_bcc => par('MAIL_FROM'),     
        p_subj      => 'Suspensión Administrativa CORREO ELECTRONICO GENERADO PARA PRUEBAS',     
        p_body      => l_body,     
        p_body_html => l_body);     
         
        APEX_MAIL.ADD_ATTACHMENT(     
            p_mail_id    => l_id,     
            p_attachment => l_response,     
            p_filename   => 'Carta Suspension Administrativa.pdf',     
            p_mime_type  => 'application/pdf');     
             
         
  end;    
  apex_mail.push_queue;    
end;
/

--Creacion de columna para guardar la subcategoria seguimiento
ALTER TABLE GES_CERTIFICADOS ADD SUBCATEGORIA NUMBER;