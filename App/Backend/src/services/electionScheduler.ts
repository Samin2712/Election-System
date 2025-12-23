import cron, { ScheduledTask } from 'node-cron';
import { pool } from '../db';

/**
 * Election Scheduler
 * Runs every minute to check for elections that need to be opened or closed
 */
class ElectionScheduler {
    private schedulerJob: ScheduledTask | null = null;

    /**
     * Start the scheduler
     */
    start() {
        if (this.schedulerJob) {
            console.log('⚠️ Election scheduler already running');
            return;
        }

        // Run every minute: '* * * * *'
        this.schedulerJob = cron.schedule('* * * * *', async () => {
            try {
                await this.processScheduledElections();
            } catch (error) {
                console.error('❌ Election scheduler error:', error);
            }
        });

        console.log('✅ Election scheduler started (runs every minute)');
    }

    /**
     * Stop the scheduler
     */
    stop() {
        if (this.schedulerJob) {
            this.schedulerJob.stop();
            this.schedulerJob = null;
            console.log('🛑 Election scheduler stopped');
        }
    }

    /**
     * Process scheduled elections
     * Opens elections that should start, closes elections that should end
     */
    private async processScheduledElections() {
        try {
            const { rows } = await pool.query(`SELECT * FROM sp_process_scheduled_elections()`);

            if (rows && rows.length > 0) {
                rows.forEach((row: any) => {
                    console.log(`📅 Election ${row.action}: "${row.election_name}" (ID: ${row.election_id})`);
                });
            }
        } catch (error: any) {
            // Log but don't crash the scheduler
            console.error('Error processing scheduled elections:', error.message);
        }
    }

    /**
     * Manually trigger processing (useful for testing)
     */
    async triggerNow() {
        console.log('🔄 Manually triggering election scheduler...');
        await this.processScheduledElections();
    }
}

// Export singleton instance
export const electionScheduler = new ElectionScheduler();
