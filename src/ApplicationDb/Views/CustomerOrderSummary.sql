CREATE VIEW [dbo].[CustomerOrderSummary]
AS
SELECT c.CustomerId, c.ExternalId, c.DisplayName,
       COUNT_BIG(o.OrderId) AS OrderCount,
       COALESCE(SUM(o.Amount), CONVERT(decimal(38,4), 0)) AS TotalAmount
FROM dbo.Customer AS c
LEFT JOIN dbo.[Order] AS o ON c.CustomerId = o.CustomerId
GROUP BY c.CustomerId, c.ExternalId, c.DisplayName;
