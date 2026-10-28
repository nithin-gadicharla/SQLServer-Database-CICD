CREATE TABLE [dbo].[Order]
(
    [OrderId] bigint IDENTITY(1,1) NOT NULL CONSTRAINT [PK_Order] PRIMARY KEY,
    [CustomerId] bigint NOT NULL,
    [Amount] decimal(19,4) NOT NULL,
    [Status] varchar(16) NOT NULL CONSTRAINT [DF_Order_Status] DEFAULT 'Pending',
    CONSTRAINT [FK_Order_Customer] FOREIGN KEY ([CustomerId]) REFERENCES [dbo].[Customer] ([CustomerId]),
    CONSTRAINT [CK_Order_Amount] CHECK ([Amount] > 0),
    CONSTRAINT [CK_Order_Status] CHECK ([Status] IN ('Pending', 'Paid', 'Cancelled'))
);
GO
CREATE INDEX [IX_Order_CustomerId] ON [dbo].[Order] ([CustomerId]) INCLUDE ([Amount], [Status]);
