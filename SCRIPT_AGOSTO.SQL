create or replace procedure send_plan2_sg (
    p_proceso_id in number,
    p_mail_to    in varchar2
) is
    l_id                number;
    l_cc                varchar2(4000);
    v_uid               varchar2(255) := sys_guid();
    v_razon_social      varchar2(255);
    v_nombre_coordinador varchar2(255);

    -- archivo de transición
    l_blob1             blob;
    l_mime1             varchar2(255);
    l_nombre_archivo1   varchar2(4000);

    -- imágenes inline
    l_logo_blob         blob;
    l_logo_mime         varchar2(255);
    l_img2_blob         blob;
    l_img2_mime         varchar2(255);

    l_body              clob;
    l_body_html         clob;
begin
    -- 1. Registrar confirmación
    insert into confirmaciones_cliente (correo, v_uid, proceso_id, fecha)
    values (p_mail_to, v_uid, p_proceso_id, date_tz_convert(sysdate));

    update bpm_procesos
       set enviado_cliente_etapa2     = 'S',
           fecha_enviado_cliente_etapa2 = date_tz_convert(sysdate)
     where id = p_proceso_id;

    -- 2. Obtener datos de razón social y coordinador
    select gcrs.razon_social
      into v_razon_social
      from ges_cliente_razon_social gcrs,
           bpm_procesos p
     where p.id = p_proceso_id
       and gcrs.id = p.razon_social_id;

    select (nombres || ' ' || apellidos)
      into v_nombre_coordinador
      from usuarios
     where id = v('USER_ID');

    -- 3. Registrar envío en log
    insert into seg_office_print (pagina, envio, proceso, correo, process)
    values ('42', 'SI', p_proceso_id, p_mail_to, 'enviar');

    -- 5. Cargar imágenes inline
    select blob_content, mime_type
      into l_logo_blob, l_logo_mime
      from apex_application_files
     where filename = 'header_plantilla.png'
       and rownum = 1;

    select blob_content, mime_type
      into l_img2_blob, l_img2_mime
      from apex_application_files
     where filename = 'body_plantilla.png'
       and rownum = 1;

    -- 6. Construir cuerpo
    l_body := 'Para ver este mensaje, por favor use un cliente de correo con HTML habilitado.';

    l_body_html := '
    <html>
      <body style="font-family:Arial, sans-serif; background:#f9f9f9;">
        <div style="text-align:center; padding:20px;">
          <!-- Header -->
          <img src="cid:logo_apex" style="max-width:600px;">

          <!-- Botón dinámico -->
          <div style="margin:10px 0;">
            <a href="'|| apex_mail.get_instance_url || 'f?p='||'283'||':36:0::::P36_UID:'||v_uid||'" 
               target="_blank"
               style="background:#ff9800; color:#fff; padding:18px 40px; 
                      font-size:18px; text-decoration:none; font-weight:bold;
                      border-radius:8px; display:inline-block;">
              👉 Ingresar al Plan de Auditoría
            </a>
          </div>

          <!-- Imagen Body, se llama instructivo pero son recomendaciones para el cliente -->
          <img src="cid:img_instructivo" style="margin:10px auto; max-width:600px; border-radius:8px;">

          <!-- Botón portal -->
          <div style="margin:10px 0; background: radial-gradient(circle at center, #C2185B 0%, #8B1A7F 30%, #6A1B5E 60%, #1976D2 85%, #0D47A1 100%)">
            <a href="https://portalclientes.icontec.org/login/" target="_blank"
               style="background:#1976D2; color:#fff; padding:18px 40px; 
                      font-size:18px; text-decoration:none; font-weight:bold;
                      border-radius:8px; display:inline-block;">
              👉 Ingresar al Portal de Clientes
            </a>
          </div>

        </div>
        <p>Cordialmente, <br><b>'|| v_nombre_coordinador ||'
      </body>
    </html>';

    -- 7. Enviar correo
    l_id := apex_mail.send(
                p_to        => 'jcespedes@icontec.org,cpinzon@icontec.org,cpachon@icontec.org',
                p_bcc       => par('MAIL_FROM'),
                p_from      => par('MAIL_FROM'),
                p_subj      => 'Plan de Auditoría - ICONTEC - TEST',
                p_body      => l_body,
                p_body_html => l_body_html);

        -- Archivo adjunto, instructivos de cliente
        FOR c1 IN (SELECT NOMBRE_ARCHIVO, TEMPLATE, MIME 
        FROM adjuntos
        WHERE ID = 383) LOOP

    APEX_MAIL.ADD_ATTACHMENT(
            p_mail_id    => l_id,
            p_attachment => c1.TEMPLATE,
            p_filename   => c1.NOMBRE_ARCHIVO,
            p_mime_type  => c1.MIME);
        END LOOP;  


    -- 9. Adjuntar imágenes inline
    apex_mail.add_attachment(
        p_mail_id    => l_id,
        p_attachment => l_logo_blob,
        p_filename   => 'logo.png',
        p_mime_type  => l_logo_mime,
        p_content_id => 'logo_apex');

    apex_mail.add_attachment(
        p_mail_id    => l_id,
        p_attachment => l_img2_blob,
        p_filename   => 'instructivo.png',
        p_mime_type  => l_img2_mime,
        p_content_id => 'img_instructivo');

    -- 10. Push a la cola
    commit;
    apex_mail.push_queue;
end send_plan2_sg;
/

create or replace procedure send_memorando_sg_prueba(p_proceso_id in number) 
is
    l_id             number;
    l_mail           ges_contactos.mail%type;
    l_cc             varchar2(4000);

    -- archivo de transición
    l_blob1          blob;
    l_mime1          varchar2(255);
    l_nombre_archivo1 varchar2(4000);

    -- imagen inline (ej: logo en APEX_APPLICATION_FILES)
    l_img_blob       blob;
    l_img_mime       varchar2(255);
begin
    -- 1. Buscar correo principal
    select mail
      into l_mail
      from ges_contactos_proceso
     where cliente_id = (select id 
                           from ges_clientes_proceso 
                          where proceso_id = p_proceso_id)
       and principal = 'S'
       and rownum = 1;

    -- 2. Buscar correos de auditores líderes
    select listagg(u.e_mail, ',') within group(order by u.e_mail)
      into l_cc
      from ges_auditores_proceso gap
      left join ges_normas_auditor gna on gap.id = gna.auditor
      join usuarios u on gap.auditor = u.id
     where gap.proceso_id = p_proceso_id
       and gna.lider = 'S'
       and u.e_mail is not null;

    -- 3. Buscar archivo de transición
    select b.archivo, b.mime, b.nombre_archivo_real
      into l_blob1, l_mime1, l_nombre_archivo1
      from bpm_img_arch_obl_transic b
     where b.transicion_id = (
               select id
                 from bpm_img_transiciones_estados
                where proceso_id = p_proceso_id
                  and estado_inicio = (
                        select id
                          from bpm_img_estados_procesos
                         where proceso_id = p_proceso_id
                           and estado = 'Programación Auditoría')
                  and estado_fin = (
                        select id
                          from bpm_img_estados_procesos
                         where proceso_id = p_proceso_id
                           and estado = 'Declaración de imparcialidad')
                  and rownum = 1
           );

    -- 4. Buscar imagen en APEX_APPLICATION_FILES (ejemplo: logo.png)
    select blob_content, mime_type
      into l_img_blob, l_img_mime
      from apex_application_files
      where filename = 'memo_plantilla.png'   -- nombre del archivo cargado
       and rownum = 1;

    -- 5. Enviar correo con referencia a la imagen inline
    l_id := apex_mail.send(
                p_to        => l_mail,
                p_cc        => l_cc,
                p_bcc       => 'jcespedes@icontec.org',
                p_from      => par('MAIL_FROM'),
                p_subj      => 'Memorando de Asignación - Test',
                p_body      => 'Adjunto encontrará el memorando',
                p_body_html => q'[
                    <html>
                      <body style="font-family:Arial, sans-serif; background:#f9f9f9;">
                        <div style="text-align:center; padding:20px;">
                          <img src="cid:logo_apex" style="margin-bottom:20px;">

                          <div style="margin:30px 0;">
                            <a href="https://portalclientes.icontec.org/login/" target="_blank"
                               style="background:#ff9800; color:#fff; 
                                      padding:20px 100px;      /* más grande */
                                      font-size:18px;        /* texto más grande */
                                      text-decoration:none; 
                                      font-weight:bold; 
                                      border-radius:8px;     /* bordes más suaves */
                                      display:inline-block;">
                              👉 Ingresar al Portal de Clientes
                            </a>
                          </div>
                        </div>
                      </body>
                    </html>
                ]'
    );

    -- 6. Adjuntar archivo de transición normal
    apex_mail.add_attachment(
        p_mail_id    => l_id,
        p_attachment => l_blob1,
        p_filename   => l_nombre_archivo1,
        p_mime_type  => l_mime1);

    -- 7. Adjuntar imagen como inline (cid:logo_apex)
    apex_mail.add_attachment(
        p_mail_id    => l_id,
        p_attachment => l_img_blob,
        p_filename   => 'logo.png',
        p_mime_type  => l_img_mime,
        p_content_id => 'logo_apex');

    -- 8. Enviar
    commit;
    apex_mail.push_queue;
end send_memorando_sg_prueba;
/
