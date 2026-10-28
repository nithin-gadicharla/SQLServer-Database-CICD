SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @external uniqueidentifier = NEWID();
    EXEC dbo.UpsertCustomer @ExternalId=@external, @DisplayName=N'CI customer';
    EXEC dbo.UpsertCustomer @ExternalId=@external, @DisplayName=N'Updated CI customer';
    IF (SELECT COUNT(*) FROM dbo.Customer WHERE ExternalId=@external) <> 1
        THROW 51010, 'Upsert created duplicate customers.', 1;
    DECLARE @customer bigint=(SELECT CustomerId FROM dbo.Customer WHERE ExternalId=@external);
    INSERT dbo.[Order](CustomerId,Amount,Status) VALUES (@customer,12.5000,'Paid');
    IF NOT EXISTS (SELECT 1 FROM dbo.CustomerOrderSummary WHERE CustomerId=@customer AND OrderCount=1 AND TotalAmount=12.5000)
        THROW 51011, 'Aggregate view result is incorrect.', 1;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
