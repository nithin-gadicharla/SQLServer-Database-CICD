CREATE PROCEDURE [dbo].[UpsertCustomer]
    @ExternalId uniqueidentifier,
    @DisplayName nvarchar(200)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @ExternalId IS NULL OR @DisplayName IS NULL OR LEN(LTRIM(RTRIM(@DisplayName))) = 0
        THROW 51001, 'ExternalId and a nonblank DisplayName are required.', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE [dbo].[Customer] WITH (UPDLOCK, SERIALIZABLE)
        SET [DisplayName] = @DisplayName WHERE [ExternalId] = @ExternalId;
        IF @@ROWCOUNT = 0
            INSERT [dbo].[Customer] ([ExternalId], [DisplayName]) VALUES (@ExternalId, @DisplayName);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
