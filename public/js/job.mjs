class MegaJob extends HTMLElement {
    #job = null;

    constructor() {
        super();
    }

    set job(item) {
        this.#job = item;
        this.#renderInnerContent();
    }

    get job() {
        return this.#job;
    }

    connectedCallback() {
        if (this.hasOwnProperty('job')) {
            const value = this.job;
            delete this.job;
            this.job = value;
        }

        if (this.#job) {
            this.#renderInnerContent();
        }
    }

    #renderInnerContent() {
        if (!this.#job) return;
        const item = this.#job;
        const isDownloading = item.status === 'downloading' || item.status === 'active';

        if (!this._initialized) {
            this.classList.add('list-group-item');

            const dFlex = document.createElement('div');
            dFlex.className = 'd-flex justify-content-between align-items-start';

            const textWrapper = document.createElement('div');
            textWrapper.className = 'text-truncate pe-2 flex-grow-1';

            this._statusText = document.createElement('strong');
            this._statusText.className = 'job-status-text';

            const br1 = document.createElement('br');

            this._time = document.createElement('small');
            this._time.className = 'text-muted job-time';

            this._timeBr = document.createElement('br');
            this._timeBr.className = 'job-time-br';

            this._link = document.createElement('small');
            this._link.className = 'text-muted job-link';

            textWrapper.append(this._statusText, br1, this._time, this._timeBr, this._link);

            this._badge = document.createElement('span');
            this._badge.className = 'badge rounded-pill mt-1 job-badge';

            dFlex.append(textWrapper, this._badge);

            this._progressContainer = document.createElement('div');
            this._progressContainer.className = 'progress mt-2 job-progress-container';
            this._progressContainer.style.height = '15px';
            this._progressContainer.style.display = 'none';

            this._progress = document.createElement('div');
            this._progress.className = 'progress-bar progress-bar-striped progress-bar-animated bg-danger job-progress';
            this._progress.setAttribute('role', 'progressbar');
            this._progress.style.width = '0%';
            this._progress.style.transition = 'width 0.3s ease';
            this._progress.setAttribute('aria-valuenow', '0');
            this._progress.setAttribute('aria-valuemin', '0');
            this._progress.setAttribute('aria-valuemax', '100');
            this._progress.textContent = '0%';

            this._progressContainer.appendChild(this._progress);

            this.append(dFlex, this._progressContainer);
            this._initialized = true;
        }

        if (isDownloading) {
            this._statusText.textContent = `Downloading... (${item.downloadedSize || 0} MB / ${item.overallSize || 0} MB)`;
        } else if (item.status === 'failed') {
            this._statusText.textContent = `Failed (Exit Code: ${item.exitCode !== undefined ? item.exitCode : 'N/A'})${item.error ? ' - ' + item.error : ''}`;
        } else if (item.status === 'error') {
            this._statusText.textContent = `Error: ${item.error || 'Unknown'}`;
        } else {
            this._statusText.textContent = item.status === 'success' ? 'Download Finished' : (item.message || 'Finished');
        }

        if (item.endTimestamp && !Number.isNaN(new Date(item.endTimestamp).getTime())) {
            this._time.textContent = `Finished at ${new Date(item.endTimestamp).toLocaleString()}`;
            this._time.style.display = '';
            this._timeBr.style.display = '';
        } else if (item.startTimestamp && !Number.isNaN(new Date(item.startTimestamp).getTime())) {
            this._time.textContent = `Started at ${new Date(item.startTimestamp).toLocaleString()}`;
            this._time.style.display = '';
            this._timeBr.style.display = '';
        } else {
            this._time.style.display = 'none';
            this._timeBr.style.display = 'none';
        }

        if ((item.status === 'success' || item.success) && item.fileName) {
            this._link.textContent = item.fileName;
        } else {
            this._link.textContent = item.link;
        }
        this._link.title = item.link;

        let badgeColor;
        switch (true) {
            case item.success:
                badgeColor = 'text-bg-danger';
                break;
            case item.status === 'downloading':
                badgeColor = 'text-bg-primary';
                break;
            case item.status === 'active':
                badgeColor = 'text-bg-secondary';
                break;
            case item.status === 'error':
            case item.status === 'notfound':
                badgeColor = 'text-bg-light';
                break;
            default:
                badgeColor = 'text-bg-dark';
                break;
        }
        this._badge.className = `badge rounded-pill mt-1 job-badge ${badgeColor}`;

        if (isDownloading) {
            this._badge.textContent = 'Active';
            this._progressContainer.style.display = '';
            const pct = item.percentage || 0;
            this._progress.style.width = `${pct}%`;
            this._progress.setAttribute('aria-valuenow', pct);
            this._progress.textContent = `${pct}%`;
        } else {
            const statusLabels = { failed: 'Failed', error: 'Error', notfound: 'Not Found', success: 'Finished' };
            this._badge.textContent = item.success ? 'Finished' : (statusLabels[item.status] || item.status || 'Failed');
            this._progressContainer.style.display = 'none';
        }
    }
}

customElements.define('mega-job', MegaJob);
