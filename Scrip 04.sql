--Campo aprobacion del cuestionario para HU 174-175
ALTER TABLE CUESTIONARIOS_RESP ADD APROBACION_CUESTIONARIO NUMBER;
--COMMIT

--Procedimiento para envio de alerta HU prioritarias HU 180  
create or replace PROCEDURE ENVIAR_CORREO_PARA_RENOVACION_CERTIFICADO_IN_ACTIVE(p_proceso_id NUMBER) IS
    v_destinatario VARCHAR2(1000) := 'yquiroz@icontec.org';
    v_mensaje CLOB;
    v_razon_social VARCHAR2(1000);
    v_validate NUMBER;
    v_codigo_certificado VARCHAR2(1000);
    l_output_filename varchar2(100) := 'Archivo'; 
    v_ejecutivo_proceso  VARCHAR2(1000);
    v_lider_cpq VARCHAR2(1000);
    v_contacto_p VARCHAR2(1000);
    v_docx BLOB;
    v_mail_id NUMBER;
    l_response BLOB;
BEGIN
    SELECT COUNT(*) 
    INTO v_validate 
    FROM BPM_PROCESOS 
    WHERE ID = p_proceso_id AND confirmacion_aud = 'S' AND confirm_p IS NULL;

    IF v_validate = 1 THEN 
        SELECT DISTINCT bp.EMAIL_EJECUTIVO, bp.MAIL_DUENO_CPQ, gc.mail, gcp.RAZON_SOCIAL, gnp.certificado_id
        INTO v_ejecutivo_proceso, v_lider_cpq, v_contacto_p, v_razon_social, v_codigo_certificado
        FROM BPM_PROCESOS bp 
        LEFT JOIN GES_CONTACTOS gc ON bp.cliente_id = gc.cliente_id
        LEFT JOIN GES_CLIENTES gcp ON bp.cliente_id = gcp.id
        LEFT JOIN GES_CERTIFICADOS gec ON bp.id = gec.proceso_id
        LEFT JOIN GES_NORMAS_PROCESOS gnp ON gnp.proceso_id = bp.id
        WHERE bp.id = p_proceso_id AND gc.principal = 'S';

        -- Generar DOCX con AOP
        v_docx := aop_api_pkg.plsql_call_to_aop(
            p_data_type       => 'PLSQL_SQL',
            p_data_source     => 'RETURN get_sql_contacto_aop(' || p_proceso_id || ');',
            p_template_type   => 'SQL',
            p_template_source => q'[
                SELECT 'docx', template 
                FROM templates 
                WHERE descripcion = 'Reactivación Administrativa'
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
                     'Cordial Saludo, amablemente adjuntamos comunicación con asunto <strong>“Reactivación de Certificado”</strong> con el fin de atender las disposiciones dadas.<br><br>' ||
                     'Teniendo en cuenta el reporte generado por nuestro sistema, respecto a la ejecución del servicio de auditoría de seguimiento más reactivación con ICONTEC, por parte de su organización, tenemos el agrado de informarles que la suspensión del certificado ha sido reversada. De acuerdo con lo anterior le confirmamos que su certificado se encuentra activo y vigente a la fecha, por lo que nos ponemos a su disposición en caso de que se requiera cualquier tipo de aclaración frente a cualquier organismo interesado.<br><br>' ||
                     'Gracias.</body></html>';

        -- Enviar correo y capturar ID
        v_mail_id := APEX_MAIL.SEND(
            p_to        => v_destinatario ||','||r.EMAIL_EJECUTIVO ||','||r.mail
            p_from      => 'send@icontec.org',
            p_bcc       => 'esotoe@icontec.org',
            p_body      => v_mensaje,
            p_body_html => v_mensaje,
            p_subj      => 'Comunicación Reactivación de certificado(s) - ' || v_razon_social
        );

        -- Adjuntar DOCX
         APEX_MAIL.ADD_ATTACHMENT(
            p_mail_id    => v_mail_id,
            p_attachment => l_response,
            p_filename   => 'Reactivación Administrativa.pdf',
            p_mime_type  => 'application/pdf'
        );

        -- Enviar correo
        APEX_MAIL.PUSH_QUEUE;

        -- Actualizar estado del certificado
        UPDATE GES_CERTIFICADOS 
        SET Estado_id = 4, FECHA_REACTIVACION = SYSDATE  
        WHERE id = v_codigo_certificado;

        COMMIT;
        
    END IF;
    END IF;
END;
/

--Campo para validacion activacion/reactivacion certificado
ALTER TABLE BPM_PROCESOS ADD CONFIRM_P NUMBER;


--envio de alerta para estado de suspendido no renovado HU 159

create or replace PROCEDURE ENVIAR_ALERTA_PARA_SUSPENSION_TECNICA IS 
    v_destinatario VARCHAR2(1000) := 'yquiroz@icontec.org';
    v_asunto VARCHAR2(1000) := 'Fin Fecha maxima para Reactivar.';
    v_mensaje CLOB;
    v_fecha_suspension DATE;
    v_razon_social VARCHAR2(2000);
BEGIN
    
    -- Iterar sobre los certificados suspendidos con fecha de suspension cumplida
    FOR r IN (

        SELECT 
         gesc.PROCESO_ID,
         gesc.NUMERO_CERTIFICADO,
         gesc.FECHA_VENCIMIENTO,
         gesc.ESTADO_ID,
         bpm.EMAIL_EJECUTIVO,
         gesc.FECHA_SUSPENSION,
         gec.RAZON_SOCIAL,
         TRUNC(gesc.FECHA_VENCIMIENTO) - TRUNC(SYSDATE) AS dias_transcurridos,
         (SELECT u.PASSWORD FROM USUARIOS u WHERE u.id = (SELECT gap.auditor FROM GES_AUDITORES_PROCESO gap WHERE COORDINADOR = 'S'  FETCH FIRST 1 ROW ONLY)) AS COORDINADOR 
         
        FROM GES_CERTIFICADOS gesc
        LEFT JOIN BPM_PROCESOS bpm ON bpm.ID = gesc.PROCESO_ID
        LEFT JOIN GES_CLIENTES gec ON gesc.CLIENTE_ID = gec.ID
        
        WHERE  TRUNC(FECHA_SUSPENSION + 180)- TRUNC(SYSDATE) = 0 AND gesc.ESTADO_ID IN (6)
    ) 
    LOOP
    --Body del mensaje 
        v_mensaje := '<html><body>Estimados,<br><br>' || CHR(10) || CHR(10) ||
                     'El certificado ' || r.NUMERO_CERTIFICADO || ' del cliente ' || r.RAZON_SOCIAL || 
                     ' no presenta programación. Solicitamos su colaboración para validar la situación del cliente y proceder con la actualización de su estado a Cancelación Técnica.<br><br>' || CHR(10) || CHR(10) ||
                     'En caso de que el servicio haya sido ejecutado o exista alguna derogación relacionada, le pedimos que nos informe dentro de los próximos 3 días hábiles. De no recibir respuesta en el plazo indicado, el certificado será actualizado automáticamente a Cancelación Técnica.<br><br>' || CHR(10) || CHR(10) ||
                     'Gracias.</body></html>';
        APEX_MAIL.SEND(
            p_to      => v_destinatario ||','||r.EMAIL_EJECUTIVO ||','|| r.COORDINADOR
            p_from    => 'send@icontec.org',
            p_bcc => 'esotoe@icontec.org',
            p_body    => v_mensaje,
            p_body_html =>v_mensaje,
            p_subj    => v_asunto
        );
    END LOOP;

    -- Forzar envio de correo
    APEX_MAIL.PUSH_QUEUE;
END;
/


--Alerta para estado de certificado vencido no renovado HU 164

create or replace PROCEDURE ENVIAR_ALERTA_PARA_VENCIDO_NO_RENOVADO IS
    v_destinatario VARCHAR2(1000) := 'yquiroz@icontec.org';
    v_asunto VARCHAR2(1000) := 'Fin Fecha Máxima para Restaurar Certificado.';
    v_mensaje CLOB;
    v_fecha_suspension DATE;
BEGIN
    
    -- Iterar sobre los certificados suspendidos con fecha de suspension cumplida
    FOR r IN (

SELECT 
         gesc.NUMERO_CERTIFICADO,
         gesc.FECHA_VENCIMIENTO,
         gec.RAZON_SOCIAL,
         gesc.ESTADO_ID,
         bpm.EMAIL_EJECUTIVO,
         gesc.FECHA_SUSPENSION,
         TRUNC(gesc.FECHA_VENCIMIENTO) - TRUNC(SYSDATE) AS dias_transcurridos,
        (SELECT u.PASSWORD FROM USUARIOS u WHERE u.id = (SELECT gap.auditor FROM GES_AUDITORES_PROCESO gap WHERE COORDINADOR = 'S'  FETCH FIRST 1 ROW ONLY)) AS COORDINADOR 

         
        FROM GES_CERTIFICADOS gesc
        LEFT JOIN BPM_PROCESOS bpm ON bpm.ID = gesc.PROCESO_ID
        LEFT JOIN GES_CLIENTES gec ON gesc.CLIENTE_ID = gec.ID

        WHERE gesc.ESTADO_ID IN (12) and  TRUNC(gesc.FECHA_VENCIMIENTO) - TRUNC(SYSDATE) = 0 AND (SELECT biep.ESTADO FROM BPM_IMG_ESTADOS_PROCESOS biep WHERE biep.ID = bpm.ESTADO_ID ) IN ('Validación Datos','Programación Auditoría')


    ) 
    LOOP
    --Body del mensaje 
        v_mensaje := '<html><body>Estimados,<br><br>' || CHR(10) || CHR(10) ||
                     'El certificado ' || r.NUMERO_CERTIFICADO || ' del cliente ' || r.RAZON_SOCIAL || 
                     ' no presenta programación. Solicitamos su colaboración para validar la situación del cliente y proceder con la actualización de su estado a Cancelación Técnica.<br><br>' || CHR(10) || CHR(10) ||
                     'En caso de que el servicio haya sido ejecutado o exista alguna derogación relacionada, le pedimos que nos informe dentro de los próximos 3 días hábiles. De no recibir respuesta en el plazo indicado, el certificado será actualizado automáticamente a Cancelación Técnica.<br><br>' || CHR(10) || CHR(10) ||
                     'Gracias.</body></html>';
        APEX_MAIL.SEND(
            p_to      => v_destinatario ,
            p_from    => 'send@icontec.org',
            p_cc => r.EMAIL_EJECUTIVO||','||r.COORDINADOR,
            p_bcc => 'esotoe@icontec.org',
            p_body    => v_mensaje,
            p_body_html =>v_mensaje,
            p_subj    => v_asunto
        );
    END LOOP;

    -- Forzar envio de correo
    APEX_MAIL.PUSH_QUEUE;
END;
/


--Envio de alerta para HU 148 Modulo Admon y control de estados 


create or replace PROCEDURE ENVIAR_ALERTA_POR_REGIONAL_CERTIFICADOS(
    p_regional VARCHAR2,
    p_correos VARCHAR2,
    p_mes VARCHAR2
) IS
    l_export   APEX_DATA_EXPORT.t_export;
    l_blob     BLOB;
    v_id NUMBER;
    v_destinatario VARCHAR2(1000) := 'yquiroz@icontec.org';
    v_mensaje CLOB;
BEGIN

    l_export := APEX_DATA_EXPORT.export (
        p_context => APEX_EXEC.OPEN_QUERY_CONTEXT(
            p_location  => APEX_EXEC.c_location_local_db,
            p_sql_query => q'[
                SELECT 
                BPS.ID,
                GCT.RAZON_SOCIAL,
                BPS.regional_ejecutivo,
                CTY.PAIS,
                GC.NUMERO_CERTIFICADO,
                (select nombre from ges_normas_tecnicas where id = GC.norma_id) AS DESCRIPCION_NORMA,
                BPS.TIPO_AUDITORIA,
                (SELECT btp.TIPO_PROCESO FROM BPM_TIPOS_PROCESOS btp WHERE btp.ID = BPS.TIPO_ID) AS "Tipo Proceso",
                GC.FECHA_MÁX_EJEC_SEG_1 AS "FECHA MAXIMA DE EJECUCION",
                GES.ESTADO,
                       CASE
                     WHEN (SELECT biep.ESTADO FROM BPM_IMG_ESTADOS_PROCESOS biep WHERE biep.ID = bps.ESTADO_ID ) in ('Validación Datos','Programación Auditoría') THEN
                      'Pendiente por programar'
                     WHEN (SELECT biep.ESTADO FROM BPM_IMG_ESTADOS_PROCESOS biep WHERE biep.ID = bps.ESTADO_ID ) in ('Declaración de imparcialidad','Plan de auditoría') THEN
                      'Programado'
                     ELSE 
                      'Ejecutado'
                    END AS "Estado de la programacion",
                 TRUNC(GC.FECHA_VENCIMIENTO) - TRUNC(SYSDATE) AS "Dias Restantes"
                FROM GES_CERTIFICADOS GC
                LEFT JOIN CIUDADES CTY ON CTY.ID = GC.CIUDAD_ID
                LEFT JOIN BPM_PROCESOS BPS ON BPS.ID = GC.PROCESO_ID
                LEFT JOIN GES_CLIENTES GCT ON GCT.ID = GC.CLIENTE_ID
                LEFT JOIN GES_ESTADOS_CERTIFICADOS GES ON GES.ID = GC.ESTADO_ID
                WHERE (GC.DUPLICADO IS NULL OR GC.DUPLICADO = 0) AND (:P273_REGIONAL IS NULL OR bps.regional_ejecutivo = :P273_REGIONAL)
                AND CASE
                WHEN (SELECT biep.ESTADO FROM BPM_IMG_ESTADOS_PROCESOS biep WHERE biep.ID = bps.ESTADO_ID) IN ('Validación Datos', 'Programación Auditoría') THEN
                'Pendiente por programar'
                WHEN (SELECT biep.ESTADO FROM BPM_IMG_ESTADOS_PROCESOS biep WHERE biep.ID = bps.ESTADO_ID) IN ('Declaración de imparcialidad', 'Plan de auditoría') THEN
                'Programado'
                ELSE 
                'Ejecutado'
                END NOT IN ('Programado', 'Ejecutado') ;
                

            ]'
        ),
        p_format       => APEX_DATA_EXPORT.c_format_xlsx,
        p_file_name    => 'reporte_actividades.xlsx'
    );

l_blob := l_export.content_blob;
    -- Construcción del cuerpo del mensaje
    v_mensaje := '<html><body>Buen día a todos.<br><br>' || CHR(10) ||
                 'Adjunto la información que no tiene programación para los meses mencionados en el asunto. ' ||
                 'La actualización de estados gestionados y programación al ' ||SYSDATE||'.<br><br>' || CHR(10) ||
                 'Para este año se tiene en cuenta la fecha máxima de suspensión. Si el certificado cruza esta fecha, ' ||
                 'inmediatamente debe cambiarse de estado a suspendido o vencido, según corresponda, ' ||
                 'si no cuenta con un permiso otorgado por la UT.<br><br>' || CHR(10) ||
                 'Recuerden que son clientes a futuro, por lo que agradecemos validar los casos para gestionar ' ||
                 'lo pertinente con el cliente antes de su fecha de cumpleaños.<br><br>' || CHR(10) ||
                 'Los estados que normalmente son enviados en este modelo son: Activos pendiente de programar.<br><br>' ||
                 'Quedo atenta a cualquier comentario o solicitud adicional.<br><br>' ||
                 'Gracias.</body></html>';

    -- Enviar correo
    v_id:=APEX_MAIL.SEND(
        p_to       => v_destinatario,
        p_from     => 'send@icontec.org',
        p_cc      => ''||p_correos||'',
        p_bcc     => 'esotoe@icontec.org',
        p_subj     => '**Correo Informativo**  Modelo Suspensión/Cancelación/Vencimiento. Meses ' || p_mes || '  Regional ' || p_regional,
        p_body     => v_mensaje,
        p_body_html => v_mensaje
    );
    
    APEX_MAIL.ADD_ATTACHMENT(
        p_mail_id => v_id,
        p_attachment => l_blob,
        p_filename => 'Clientes sin programación.xlsx',
        p_mime_type => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    );
    -- Forzar envío del correo
    APEX_MAIL.PUSH_QUEUE;
END;
/

--Envio de alerta para HU 151 Modulo Admon y control de estados 
create or replace PROCEDURE ENVIAR_ALERTA_POR_REGIONAL_CERTIFICADOS_ESTADOS(
    p_regional VARCHAR2,
    p_mes      VARCHAR2
) IS
    v_mensaje      CLOB;
    v_destinatario VARCHAR2(1000) := 'yquiroz@icontec.org';
BEGIN
    FOR r IN (

SELECT 
    DISTINCT BPS.ID,
    BPS.EMAIL_EJECUTIVO,
    GCC.NOMBRES ,
    GCC.MAIL,
    GCT.RAZON_SOCIAL,
    BPS.REGIONAL_EJECUTIVO,
    GC.NUMERO_CERTIFICADO,
    GES.ESTADO,
    BPS.CLIENTE_ID
FROM GES_CERTIFICADOS GC
LEFT JOIN CIUDADES CTY ON CTY.ID = GC.CIUDAD_ID
LEFT JOIN GES_CONTACTOS GCC ON  GCC.CLIENTE_ID = GC.CLIENTE_ID 
LEFT JOIN BPM_PROCESOS BPS ON BPS.ID = GC.PROCESO_ID
LEFT JOIN GES_CLIENTES GCT ON GCT.ID = GC.CLIENTE_ID
LEFT JOIN GES_ESTADOS_CERTIFICADOS GES ON GES.ID = GC.ESTADO_ID
LEFT JOIN BPM_IMG_ESTADOS_PROCESOS BIEP ON BIEP.ID = BPS.ESTADO_ID
LEFT JOIN BPM_TIPOS_PROCESOS BTP ON BTP.ID = BPS.TIPO_ID
WHERE (GC.DUPLICADO IS NULL OR GC.DUPLICADO = 0) AND BPS.REGIONAL_EJECUTIVO = p_regional AND GCC.CREATED = (SELECT MAX(CREATED) FROM GES_CONTACTOS WHERE CLIENTE_ID = GC.CLIENTE_ID) AND GCC.PRINCIPAL = 'S'
AND CASE
WHEN (SELECT biep.ESTADO FROM BPM_IMG_ESTADOS_PROCESOS biep WHERE biep.ID = bps.ESTADO_ID) IN ('Validación Datos', 'Programación Auditoría') THEN
'Pendiente por programar'
WHEN (SELECT biep.ESTADO FROM BPM_IMG_ESTADOS_PROCESOS biep WHERE biep.ID = bps.ESTADO_ID) IN ('Declaración de imparcialidad', 'Plan de auditoría') THEN
'Programado'
ELSE 
'Ejecutado'
END NOT IN ('Programado', 'Ejecutado')
    ) LOOP

        -- Construcción del cuerpo del mensaje
        v_mensaje := '<html><body>' ||
                     'Estimado(a) ' || r.NOMBRES || ':<br><br>' ||
                     'Nos ponemos en contacto con usted con motivo de informarle que a la fecha nuestro sistema no reporta programación de su servicio de auditoría para su certificado No. ' || r.NUMERO_CERTIFICADO || '.<br><br>' ||
                     'Cualquier inquietud respecto al proceso, manejo y responsabilidad respecto a estas actividades, lo invitamos a revisar el reglamento de la certificación correspondiente a su esquema, en el capítulo “Mantenimiento de la certificación”, o puede comunicarse directamente con su ejecutivo de cuenta o informarnos a través de este medio para activar gestiones de nuestra parte.<br><br>' ||
                     'Si a la fecha de recibir este comunicado su auditoría ya fue notificada o se encuentra en proceso de formalización con ICONTEC, por favor hacer caso omiso a este mensaje.<br><br>' ||
                     'Gracias.<br>' ||
                     '</body></html>';

        APEX_MAIL.SEND(
            p_to         => v_destinatario ||','||r.mail||','|| r.EMAIL_EJECUTIVO,
            p_from       => 'send@icontec.org',
            p_bcc        => 'esotoe@icontec.org',
            p_subj       => 'PREAVISO - ' || r.RAZON_SOCIAL,
            p_body       => v_mensaje,
            p_body_html  => v_mensaje
        );

        -- Forzar envío del correo
        APEX_MAIL.PUSH_QUEUE;
    END LOOP;
END;
/
