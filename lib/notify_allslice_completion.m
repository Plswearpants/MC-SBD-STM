function notify_allslice_completion(output_file, run_slice_idx, run_kernel_idx)
%NOTIFY_ALLSLICE_COMPLETION Announce that an all-slice block run finished.
%   notify_allslice_completion(output_file, run_slice_idx, run_kernel_idx)
%
%   Always prints a summary and appends a completion marker next to the
%   output file so external watchers can poll for it. Additionally attempts,
%   best effort and never fatally:
%       - a local beep + message box (desktop sessions only)
%       - a webhook POST when MC_SBD_NOTIFY_WEBHOOK_URL is set
%       - an email when MC_SBD_NOTIFY_EMAIL is set
%
%   Promoted from a local function in historical/real/hist_MCSBD_block_realdata1.m so
%   that wrappers (runAllSlicesReal) can call it directly.

    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    summary_msg = sprintf(['MC-SBD all-slice block finished at %s. ', ...
        'Slices=%s, Kernels=%s. Output=%s'], ...
        timestamp, mat2str(run_slice_idx), mat2str(run_kernel_idx), output_file);
    fprintf('%s\n', summary_msg);

    % Always create an in-folder completion marker for external watchers.
    [output_dir, ~, ~] = fileparts(output_file);
    marker_file = fullfile(output_dir, 'ALL_SLICE_RUN_DONE.txt');
    fid = fopen(marker_file, 'a');
    if fid >= 0
        fprintf(fid, '[%s] %s\n', timestamp, summary_msg);
        fclose(fid);
    end

    % Local alert (works without any external setup).
    try
        for ii = 1:3
            beep;
            pause(0.15);
        end
        if usejava('desktop')
            msgbox(summary_msg, 'MC-SBD All-slice Finished', 'help');
        end
    catch
        % Non-interactive sessions may not support popup/beep.
    end

    % Optional webhook notification (Slack/Discord/custom endpoint).
    webhook_url = getenv('MC_SBD_NOTIFY_WEBHOOK_URL');
    if ~isempty(webhook_url)
        try
            payload = struct();
            payload.text = summary_msg;
            payload.output_file = output_file;
            payload.timestamp = timestamp;
            payload.slices = run_slice_idx;
            payload.kernels = run_kernel_idx;
            opts = weboptions('MediaType', 'application/json', 'Timeout', 20);
            webwrite(webhook_url, payload, opts);
            fprintf('Webhook notification sent.\n');
        catch ME
            warning('Webhook notification failed: %s', ME.message);
        end
    end

    % Optional email notification.
    email_to = getenv('MC_SBD_NOTIFY_EMAIL');
    if ~isempty(email_to)
        try
            configure_sendmail_from_env();
            subject = 'MC-SBD all-slice block finished';
            sendmail(email_to, subject, summary_msg);
            fprintf('Email notification sent to %s.\n', email_to);
        catch ME
            warning(['Email notification failed: %s. ', ...
                'Set SMTP env vars or configure sendmail in MATLAB preferences.'], ME.message);
        end
    end
end

function configure_sendmail_from_env()
    % Optional SMTP auto-configuration from environment variables:
    %   MC_SBD_SMTP_SERVER       (e.g. smtp.gmail.com)
    %   MC_SBD_SMTP_PORT         (e.g. 465 or 587)
    %   MC_SBD_SMTP_USERNAME     (sender/login email)
    %   MC_SBD_SMTP_PASSWORD     (app password/token)
    %   MC_SBD_SMTP_SENDER       (optional; defaults to username)
    %   MC_SBD_SMTP_USE_SSL      (optional: 0/1; default 1 for port 465)
    %   MC_SBD_SMTP_USE_STARTTLS (optional: 0/1; default 1 for port 587)
    smtp_server = getenv('MC_SBD_SMTP_SERVER');
    smtp_port_str = getenv('MC_SBD_SMTP_PORT');
    smtp_username = getenv('MC_SBD_SMTP_USERNAME');
    smtp_password = getenv('MC_SBD_SMTP_PASSWORD');
    smtp_sender = getenv('MC_SBD_SMTP_SENDER');
    use_ssl_str = getenv('MC_SBD_SMTP_USE_SSL');
    use_starttls_str = getenv('MC_SBD_SMTP_USE_STARTTLS');

    if isempty(smtp_server) || isempty(smtp_username) || isempty(smtp_password)
        % Respect existing MATLAB sendmail configuration.
        return;
    end

    if isempty(smtp_sender)
        smtp_sender = smtp_username;
    end

    if isempty(smtp_port_str)
        smtp_port = 465;
    else
        smtp_port = str2double(smtp_port_str);
        if isnan(smtp_port) || smtp_port <= 0
            error('Invalid MC_SBD_SMTP_PORT: %s', smtp_port_str);
        end
    end

    use_ssl = default_bool_from_port(use_ssl_str, smtp_port == 465);
    use_starttls = default_bool_from_port(use_starttls_str, smtp_port == 587);

    setpref('Internet', 'E_mail', smtp_sender);
    setpref('Internet', 'SMTP_Server', smtp_server);
    setpref('Internet', 'SMTP_Username', smtp_username);
    setpref('Internet', 'SMTP_Password', smtp_password);

    props = java.lang.System.getProperties;
    props.setProperty('mail.smtp.auth', 'true');
    props.setProperty('mail.smtp.port', num2str(smtp_port));
    props.setProperty('mail.smtp.socketFactory.port', num2str(smtp_port));
    if use_ssl
        props.setProperty('mail.smtp.socketFactory.class', 'javax.net.ssl.SSLSocketFactory');
    else
        props.remove('mail.smtp.socketFactory.class');
    end
    if use_starttls
        props.setProperty('mail.smtp.starttls.enable', 'true');
    else
        props.setProperty('mail.smtp.starttls.enable', 'false');
    end
end

function value = default_bool_from_port(raw_value, default_value)
    if isempty(raw_value)
        value = default_value;
        return;
    end
    value = strcmp(raw_value, '1') || strcmpi(raw_value, 'true') || strcmpi(raw_value, 'yes');
end
