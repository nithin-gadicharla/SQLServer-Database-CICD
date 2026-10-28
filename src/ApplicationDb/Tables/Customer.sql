CREATE TABLE [dbo].[Customer]
(
    [CustomerId] bigint IDENTITY(1,1) NOT NULL CONSTRAINT [PK_Customer] PRIMARY KEY,
    [ExternalId] uniqueidentifier NOT NULL,
    [DisplayName] nvarchar(200) NOT NULL,
    [CreatedAtUtc] datetime2(3) NOT NULL CONSTRAINT [DF_Customer_CreatedAtUtc] DEFAULT SYSUTCDATETIME(),
    [RowVersion] rowversion NOT NULL,
    CONSTRAINT [UQ_Customer_ExternalId] UNIQUE ([ExternalId]),
    CONSTRAINT [CK_Customer_DisplayName] CHECK (LEN(LTRIM(RTRIM([DisplayName]))) > 0)
);
